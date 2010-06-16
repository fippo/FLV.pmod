//! FLV File reader / writer
//! reads and writes Flash Video File format
//! as specified in 
//! http://www.adobe.com/devnet/flv/pdf/video_file_format_spec_v9.pdf
//! variable naming similar to spec for convenience
//! @note
//!	using pike with 64 bit doubles is recommended.

//! underlying file
Stdio.File file;

//! The name of the file
string filename;

//! three byte file signature  - always "FLV"
string signature = "FLV";

//! file format version - usually 1.0
int version;

//! type flags
int typeflags;

//! offset in bytes from start of file to start of body (i.e. size of header)
int dataoffset;

//! if the file contains audio data according to header
int(0..1) has_audio;

//! if the file contains video data according to header
int(0..1) has_video;

//! the largest timestamp written to file
int max_timestamp;

string mode;

int(0..1) header_read = 0;

void create(string|void filename, string|void mode, int|void mask) {
	if (filename) {
		this->filename = filename;
		this->mode = mode;
		if (!mode) {
			mode = "r";
		}
	} 
	file = Stdio.File();
	if (filename) {
		open(filename, mode, mask);
	}
}

int open(string filename, string mode, int|void mask) {
	this->filename = filename;
	this->mode = mode;
	int ret = file->open(filename, mode, mask);
	return ret;
}

int is_open() {
	return file != 0 && file->is_open();
}

int tell() {
	return file->tell();
}

int raw_seek(int pos) {
	return file->seek(pos);
}

//! reads the header of the file
//! and sets the variables signature, version, flags, offset and total length
//! MUST be called before read() 
mixed read_header() {
	string t;
	if (header_read) {
		werror("%s read_header called twice\n", filename); // error?
		return ({ version, typeflags, dataoffset });
	}
	t = file->read(13);
	/* 3 bytes: 'FLV'
	 * 1 byte : version - 0x01 usually
	 * 1 byte : typeflags
	 * 		bits 1-5: typeflagsresevered, must be 0
	 * 		bit    6: typeflags audio - specifies if audio tags are present
	 * 		bit    7: typeflagsresevered, must be 0
	 * 		bit    8: typeflags video - specifies if video tags are present
	 * 4 bytes: dataoffset - 9 usually
	 * 4 bytes: PreviousTagSize0 - always 0
	 */
	if (sscanf(t, "FLV%c%c%4c\0\0\0\0", version, typeflags, dataoffset) != 3) {
		error("FLV %s: invalid header", filename);
	}
	header_read = 1;
	has_audio = (typeflags & 0b00000100) >> 2;
	has_video = typeflags & 0b00000001;

	return ({ version, typeflags, dataoffset });
}

//! writes a a header using variables header, version, typeflags and offset 
//! (or defaults if those variables are not given
//! Note: it is a good idea to reserve space for metadata afterwards by writing dummy metadata there to reserve space
void write_header() {
	file->seek(0);
	file->write("FLV%1c%1c%4c%4c", version || 0x01, typeflags || 0x05, dataoffset || 0x09, 0);
}

//! writes a single chunk to the file
//! @param tag_type
//! 	tag type - usually 0x08 (audio) or 0x09 (video), possibly 0x12 (script data)
//! @param timestamp
//!	data timestamp in milliseconds
//! @param data
//!	tag data
//! @returns
//!	number of bytes written
int write(int tag_type, int timestamp, string data) {
	file->write("%1c%3c%3c%c\0\0\0%s%4c", 
		    tag_type, sizeof(data), 
		    timestamp & 0xffffff, (timestamp & 0xff000000) >> 24, 
		    data, 11+sizeof(data));
	timestamp = max(timestamp, max_timestamp);
}

//! reads a single tag from the file
//! @param backwards
//!	if set, read backwards (i.e. starting from the end of the file)
//! @returns
//!	array ({ tag_type, timestamp, data })
//!	or 0 if there was an error or there is no more tag
mixed read(int|void backwards) {
	string t;
	int tag_type, data_size, timestamp, timestamp_extended, previous_tag_size;
	int pos;

	if (backwards) {
		file->seek(file->tell() - 4);
		t = file->read(4);
		if (!t) {
			return 0;
		}
		sscanf(t, "%4c", previous_tag_size);
		if (!previous_tag_size) {
			return 0;
		}
		pos = file->tell() - 4 - previous_tag_size;
		file->seek(pos);
	} else {
		// FIXME: is this warning really needed?
		/*
		if (!header_read) {
			error("read_header() must be called before read\n");
		}
		*/
	}

	t = file->read(11);
	if (strlen(t) != 11) {
		return 0;
	}
	// FIXME: this ignores streamid which should be 0
	sscanf(t, "%c%3c%3c%c%*3c", tag_type, data_size, timestamp, timestamp_extended);
	timestamp += timestamp_extended << 24;
	string data = file->read(data_size);

	if (backwards) {
		file->seek(pos);
	} else {
		t = file->read(4); // previous tag size
	}
	return ({ tag_type, timestamp, data });
}

//! closes the file
int close() {
	/*
	if (mode == "w" || mode == "cw")
		write_metadata();
		*/
	return file->close();
}
