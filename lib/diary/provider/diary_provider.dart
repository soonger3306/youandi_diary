import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youandi_diary/diary/model/diary_model.dart';
import 'package:youandi_diary/user/model/user_model.dart';

final diaryProvider = Provider<DiaryRepository>((ref) => DiaryRepository());
final diaryListProvider = ChangeNotifierProvider<DiaryListNotifier>(
    (ref) => DiaryListNotifier(repository: ref.read(diaryProvider)));

class DiaryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 다이어리 생성
  Future<DiaryModel> saveDiaryToFirestore(DiaryModel diary) async {
    DocumentReference docRef = _firestore.collection('diary').doc();
    DocumentReference userRef = _firestore
        .collection('user')
        .doc(currentUser?.uid)
        .collection('diary')
        .doc(docRef.id);
    final userData = {
      'diaryId': docRef.id,
      'title': diary.title,
      'dataTime': DateTime.now(),
      'coverImg': diary.coverImg,
      'memberUids': diary.member.map((UserModel user) => user.uid).toList(),
      'member': diary.member.map((UserModel user) => user.toJson()).toList(),
    };
    if (diary.diaryId == null) {
      // Save the data to both locations
      await docRef.set(userData);
      await userRef.set(userData);

      // Update the model's ID
      diary.diaryId = docRef.id;
    }

    return diary;
  }

  Future<DiaryModel?> getDiaryById(String diaryId) async {
    final DocumentSnapshot snapshot =
        await _firestore.collection('diary').doc(diaryId).get();

    if (snapshot.exists) {
      return DiaryModel.fromJson(snapshot.data() as Map<String, dynamic>);
    } else {
      return null;
    }
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  Future<List<DiaryModel>> getDiaryListFromFirestore() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('diary')
        .where('memberUids', arrayContains: currentUser!.uid)
        .orderBy(
          'dataTime',
          descending: true,
        )
        .get();
    final List<DiaryModel> diaryList = [];
    for (var doc in snapshot.docs) {
      diaryList.add(DiaryModel.fromJson(doc.data() as Map<String, dynamic>));
    }

    return diaryList;
  }

  // 다이어리와 하위 컬렉션 삭제
  Future<void> deleteDiaryWithSubcollections({
    required String diaryId,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();

      // diary > post 컬렉션에서 해당 다이어리의 모든 포스트 찾아서 삭제
      QuerySnapshot diaryPostsSnapshot = await _firestore
          .collection('diary')
          .doc(diaryId)
          .collection('post')
          .get();

      for (DocumentSnapshot postDoc in diaryPostsSnapshot.docs) {
        // 해당 포스트의 모든 댓글 찾아서 삭제
        QuerySnapshot commentsSnapshot =
            await postDoc.reference.collection('comment').get();

        for (DocumentSnapshot commentDoc in commentsSnapshot.docs) {
          // user > comment 에서 해당 댓글 찾아서 확인 후 내 댓글인 경우만 삭제
          DocumentReference userCommentRef = _firestore
              .collection('user')
              .doc(currentUser?.uid)
              .collection('comment')
              .doc(commentDoc.id);

          DocumentSnapshot userCommentSnap = await userCommentRef.get();

          if (userCommentSnap.exists) {
            Map<String, dynamic> data =
                userCommentSnap.data() as Map<String, dynamic>;
            if (data['userId'] == currentUser?.uid) {
              batch.delete(userCommentRef);
              batch.delete(commentDoc.reference);
            }
          }
        }

        // 포스트 자체를 삭제
        batch.delete(postDoc.reference);

        // user -> posts 에서 포스트 자체를 확인 후 내 글인 경우만 삭제
        DocumentReference userPostRef = _firestore
            .collection('user')
            .doc(currentUser?.uid)
            .collection('post')
            .doc(postDoc.id);

        DocumentSnapshot userPostSnap = await userPostRef.get();
        if (userPostSnap.exists) {
          Map<String, dynamic> postData =
              userPostSnap.data() as Map<String, dynamic>;
          if (postData['userId'] == currentUser?.uid) {
            batch.delete(userPostRef);
          }
        }
      }

      // 마지막으로 다이어리 자체를 확인 후 내 다이어리인 경우만 삭제
      DocumentReference diaryRef = _firestore.collection('diary').doc(diaryId);

      DocumentSnapshot diarySnap = await diaryRef.get();
      if (diarySnap.exists) {
        Map<String, dynamic> diaryData =
            diarySnap.data() as Map<String, dynamic>;
        if (diaryData['userId'] == currentUser?.uid) {
          batch.delete(diaryRef);
        }
      }

      await batch.commit();
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> removeUserFromDiary({
    required String diaryId,
  }) async {
    try {
      DocumentReference diary = _firestore.collection('diary').doc(diaryId);

      DocumentSnapshot docSnapshot = await diary.get();

      Map<String, dynamic>? data = docSnapshot.data() as Map<String, dynamic>?;
      if (data != null &&
          data.containsKey('memberUids') &&
          data.containsKey('member')) {
        List<String> memberUids = List<String>.from(data['memberUids']);
        List<UserModel> members = (data['member'] as List)
            .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
            .toList();

        UserModel currentUserModel =
            members.firstWhere((user) => user.uid == currentUser!.uid);

        if (memberUids.contains(currentUser!.uid)) {
          if (memberUids.length == 1) {
            await diary.delete();
          } else {
            // Otherwise, remove their UID from the 'memberUids' field.
            final updates = {
              'memberUids': FieldValue.arrayRemove([currentUser!.uid]),
              'member': FieldValue.arrayRemove([currentUserModel.toJson()]),
            };

            diary.update(updates);
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }
}

class DiaryListNotifier with ChangeNotifier {
  DiaryListNotifier({required this.repository}) {
    loadDiaries();
  }

  final DiaryRepository repository;
  List<DiaryModel> _diaryList = [];
  bool _isLoading = false;

  List<DiaryModel> get diaryList => _diaryList;
  bool get isLoading => _isLoading;

  Future<void> addDiary(DiaryModel diary) async {
    if (_diaryList.contains(diary)) {
      return;
    }
    _isLoading = true;
    notifyListeners();
    await repository.saveDiaryToFirestore(diary);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDiaries() async {
    _isLoading = true;
    notifyListeners();
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;

      notifyListeners();
      return;
    }
    repository._firestore
        .collection('diary')
        .where('memberUids', arrayContains: user.uid)
        .orderBy('dataTime', descending: true)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      final List<DiaryModel> newDiaryList = [];
      for (var doc in snapshot.docs) {
        newDiaryList.add(
          DiaryModel.fromJson(
            doc.data() as Map<String, dynamic>,
          ),
        );
      }

      _diaryList = newDiaryList;
      _isLoading = false;
      notifyListeners();
    });
  }
}
