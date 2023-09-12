import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:youandi_diary/diary/component/custom_video_player.dart';
import 'package:youandi_diary/diary/model/diary_post_model.dart';
import 'package:youandi_diary/diary/provider/diary_provider.dart';
import 'package:youandi_diary/user/layout/default_layout.dart';

import '../../common/const/color.dart';

class DiaryPostScreen extends ConsumerStatefulWidget {
  static String get routeName => 'post';
  const DiaryPostScreen({super.key});

  @override
  ConsumerState<DiaryPostScreen> createState() => _DiaryPostScreenState();
}

class _DiaryPostScreenState extends ConsumerState<DiaryPostScreen> {
  List<XFile> selectedImages = [];

  XFile? video;
  VideoPlayerController? videoController;
  Duration currentPosition = const Duration();
  bool showControls = false;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  @override
  Widget build(
    BuildContext context,
  ) {
    final provider = ref.watch(diaryProvider);

    return DefaultLayout(
      color: DIARY_DETAIL_COLOR,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    mediaDialog(context);
                  },
                  child: Container(
                    height: MediaQuery.of(context).size.height / 3.5,
                    width: MediaQuery.of(context).size.width - 70,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: WHITE_COLOR,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(
                        50,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        50,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (selectedImages.isEmpty && video == null)
                            Image.asset(
                              'asset/image/icon/photo.png',
                              scale: 4,
                            ),
                          if (selectedImages.isEmpty && video == null)
                            const Text(
                              'add photo & video +',
                              style: TextStyle(
                                color: WHITE_COLOR,
                                fontSize: 20,
                              ),
                            ),
                          if (selectedImages.isNotEmpty)
                            Expanded(
                              child: PageView.builder(
                                itemCount: selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Center(
                                        child: Image.file(
                                          File(selectedImages[index].path),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        right: 10.0,
                                        child: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedImages.removeAt(index);
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.remove_circle_outlined,
                                            size: 30,
                                            color: WHITE_COLOR,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          if (video != null)
                            Stack(
                              children: [
                                CustomVideoPlayer(
                                    onNewVideoPressed: onNewVideoPressed,
                                    video: video!),
                                Positioned(
                                  right: 10.0,
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        video = null;

                                        videoController?.dispose();
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.remove_circle_outlined,
                                      size: 30,
                                      color: WHITE_COLOR,
                                    ),
                                  ),
                                ),
                              ],
                            )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 30,
                ),
                Container(
                  color: ADD_BG_COLOR,
                  height: MediaQuery.of(context).size.height / 2.2,
                  width: MediaQuery.of(context).size.width - 70,
                  child: Form(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              hintText: '제목',
                              // border: OutlineInputBorder(
                              //   borderSide: BorderSide(color: Colors.grey, width: 2.0),
                              // ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: TEXT_OUTLINE_COLOR,
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                          TextFormField(
                            controller: contentController,
                            autocorrect: true,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: '내용',
                              border: InputBorder.none,
                              focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(), //<-- SEE HERE
                    padding: const EdgeInsets.all(20),
                  ),
                  onPressed: () async {
                    List<String>? imageUrlList = [];
                    String? videoUrl;

                    String postTitle = titleController.text;
                    String content = contentController.text;

                    List<String> imgUrl = imageUrlList;

                    for (var image in selectedImages) {
                      try {
                        String imageUrl =
                            await uploadFileToFirebaseStorage(image, 'youandi');
                        imageUrlList.add(imageUrl);
                      } catch (error) {
                        print('Failed to upload image: $error');
                        // 필요한 경우 여기에서 추가적인 에러 처리 로직 구현
                      }
                    }
                    if (video != null) {
                      try {
                        videoUrl =
                            await uploadFileToFirebaseStorage(video!, 'videos');
                      } catch (error) {
                        print('Failed to upload video:$error');
                      }
                    }

                    // 새 DiaryPostModel 생성
                    DiaryPostModel newDiaryPost = DiaryPostModel(
                      title: postTitle,
                      content: content,
                      videoUrl: videoUrl.toString(),
                      imgUrl: imgUrl,
                      dataTime: DateTime.now(), // 현재 시간으로 설정
                      // 나머지 필드들은 선택적이므로 초기값(null)이 할당됩니다.
                    );
                    provider.savePostToFirestore(newDiaryPost);
                  },
                  child: const Text(
                    '글작성',
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<dynamic> mediaDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        final content = Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: () {
                      _getCamera();
                    },
                    child: const Text("카메라"),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  TextButton(
                    onPressed: () {
                      getImages();
                    },
                    child: const Text("사진"),
                  ),
                  TextButton(
                    onPressed: () {
                      pickVideo(ImageSource.gallery);
                    },
                    child: const Text("동영상"),
                  ),
                  const Divider(
                    height: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(
                  Radius.circular(
                    10.0,
                  ),
                ),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "취소",
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 40,
            ),
          ],
        );
        return FractionallySizedBox(
          widthFactor: 0.9,
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        );
      },
    );
  }

  Future<String> uploadFileToFirebaseStorage(
      XFile xfile, String directory) async {
    String uniqueFileName = DateTime.now().microsecondsSinceEpoch.toString();
    Reference referenceRoot = FirebaseStorage.instance.ref();
    Reference referenceDir = referenceRoot.child(directory);
    Reference referenceFileToUpload = referenceDir.child(uniqueFileName);

    try {
      File file = File(xfile.path); // XFile의 path 속성을 사용하여 File 객체 생성
      await referenceFileToUpload.putFile(file);
      String fileUrl = await referenceFileToUpload.getDownloadURL();
      return fileUrl;
    } catch (error) {
      print('Error occurred while uploading file: $error');
      rethrow; // 에러를 다시 던져 호출자가 처리하도록 함
    }
  }

  void onNewVideoPressed() async {
    final video = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    setState(() {
      this.video = video;
    });
  }

  void onSliderChanged(double val) {
    videoController!.seekTo(
      Duration(seconds: val.toInt()),
    );
  }

  void onReversePressed() {
    final currentPosition = videoController!.value.position;

    Duration position = const Duration(); // 0초

    if (currentPosition.inSeconds > 2) {
      position = currentPosition - const Duration(seconds: 2);
    }

    videoController!.seekTo(position);
  }

  void onPlayPressed() {
    // 이미 실행중이면 중지
    // 실행중이면 중지

    setState(() {
      if (videoController!.value.isPlaying) {
        videoController!.pause();
      } else {
        videoController!.play();
      }
    });
  }

  void onForwardPressed() {
    // 전체 총길이
    final maxPosition = videoController!.value.duration;
    final currentPosition = videoController!.value.position;
    Duration position = maxPosition;
    if ((maxPosition - const Duration(seconds: 2)).inSeconds >
        currentPosition.inSeconds) {
      position = currentPosition + const Duration(seconds: 2);
    }

    videoController!.seekTo(position);
  }

  _getCamera() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        video = pickedFile;
      });
    } else {
      if (kDebugMode) {
        print('이미지 선택안함');
      }
    }
  }

  final picker = ImagePicker();
  Future getImages() async {
    final pickedFile = await picker.pickMultiImage(
        imageQuality: 100, maxHeight: 1000, maxWidth: 1000);
    List<XFile> xfilePick = pickedFile;

    if (xfilePick.isNotEmpty) {
      for (var i = 0; i < xfilePick.length; i++) {
        selectedImages.add(xfilePick[i]);
      }
      video = null;
      setState(
        () {
          context.pop();
        },
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing is selected')));
    }
  }

  Future pickVideo(ImageSource source) async {
    final video = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    this.video = video;
    selectedImages.clear();
    context.pop();
    setState(() {});
  }
}
