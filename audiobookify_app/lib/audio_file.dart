import 'package:json_annotation/json_annotation.dart';

part 'audio_file.g.dart';

@JsonSerializable()
class AudioFile {
  final String fileName;
  final String url;

  AudioFile({required this.fileName, required this.url});

  factory AudioFile.fromJson(Map<String, dynamic> json) =>
      _$AudioFileFromJson(json);
  Map<String, dynamic> toJson() => _$AudioFileToJson(this);
}
