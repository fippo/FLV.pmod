// vim:syntax=lpc
constant __author = "Philipp Hancke <fippo@mail.symlynx.com>";
constant __version = "0.1";

//! This module provides an interface to the Flash Video File format as 
//! specified in version 9 of the video file format specification 
//! available at http://www.adobe.com/devnet/flv/

constant tag_audio = 0x08;
constant tag_video = 0x09;
constant tag_meta = 0x12;

//! decodes a audio tag
//! @param data
//! 	data extracted from flv - 1 byte flag followed by audio data
//! @returns
//!	mapping with decoded flags and audio data
mapping audio_tag(string data) {
	mapping t = ([ ]);
	int flags = data[0];
	t["soundFormat"] = (flags & 0b11110000) >> 4;
	t["soundRate"] = (flags & 0b00001100) >> 2;
	t["soundSize"] = (flags & 0b00000010) >> 1;
	t["soundType"] = (flags & 0b00000001);
	t["soundData"] = data[1..];
	return t;
}

//! decodes a video tag
//! @param data
//! 	data extracted from flv - 1 byte flag followed by video data
//! @returns
//!	mapping with decoded flags and video data
mapping video_tag(string data) {
	mapping t = ([ ]);
	int flags = data[0];
	t["frameType"] = (flags & 0b11110000) >> 4;
	t["codecID"] = (flags & 0b00001111);
	t["videoData"] = data[1..];
	return t;
}
