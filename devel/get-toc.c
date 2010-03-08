/* $Id$ */
#define INCL_DOSDEVICES
#define INCL_DOSDEVIOCTL
#include <os2.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void whoops(char *message) {
	printf("1000\t0\t0\t%s\n", message);
}

void usage(char *fname) {
	fprintf(
		stderr, 
		"%s requires one parameter, a CD-ROM drive letter\n",
		fname
	);
	whoops("Invoked incorrectly");
	exit(1);
}

#pragma pack(1)
typedef struct _getaudiodiskparm {
	UCHAR signature[4];
} GetAudioDiskParm;

/* endian dependent; coded for intel */
typedef struct _msfulong {
	UCHAR frames;
	UCHAR secs;
	UCHAR mins;
	UCHAR junk;
} MSFULONG;

typedef struct _getaudiodiskdata {
	UCHAR start_track;
	UCHAR final_track;
	MSFULONG lead_out_address;
} GetAudioDiskData;

typedef struct _getaudiotrackparm {
	UCHAR signature[4];
	UCHAR track_number;
} GetAudioTrackParm;

typedef struct _getaudiotrackdata {
	MSFULONG track_address;
	UCHAR track_info;
} GetAudioTrackData;
#pragma pack(4)

ULONG msf_frame(MSFULONG msf) {
	return ((((msf.mins * 60) + (msf.secs)) * 75) + msf.frames);
}

char errbuf[256];

int main(int argc, char **argv) {
	HFILE drive;
	ULONG action, ulParmLen, ulDataLen;
	GetAudioDiskParm parmGAD;
	GetAudioDiskData dataGAD;
	GetAudioTrackParm parmGAT;
	GetAudioTrackData dataGAT;
	APIRET rc;
	int track;

	if (argc != 2) { usage(argv[0]); }
	if (strlen(argv[1]) != 2) { usage(argv[0]); }
	if (argv[1][1] != ':') { usage(argv[0]); }
	strupr(argv[1]);
	if ((argv[1][0] < 'A') || (argv[1][0] > 'Z')) { usage(argv[0]); }
																/* open the cd player */
	rc = DosOpen(
		argv[1], &drive, &action, 0, 0,
		OPEN_ACTION_FAIL_IF_NEW | OPEN_ACTION_OPEN_IF_EXISTS,
		OPEN_FLAGS_DASD | OPEN_FLAGS_FAIL_ON_ERROR |
		OPEN_FLAGS_NO_CACHE | OPEN_SHARE_DENYNONE |
		OPEN_ACCESS_READONLY,
		NULL
	);
	if (rc) {
		sprintf(errbuf, "error %ld opening cdrom device '%s'\n", rc, argv[1]);
		whoops(errbuf);
		exit(1);
	}
																/* get the track range */
	memcpy(parmGAD.signature, "CD01", 4);
	memset(&dataGAD, 0, sizeof(dataGAD));
	rc = DosDevIOCtl(
		drive, IOCTL_CDROMAUDIO, CDROMAUDIO_GETAUDIODISK,
		&parmGAD, ulParmLen = sizeof(parmGAD), &ulParmLen,
		&dataGAD, ulDataLen = sizeof(dataGAD), &ulDataLen
	);
	if (rc) {
		sprintf(errbuf, "Could not acquire start and end track numbers: %ld", rc);
		whoops(errbuf);
		exit(1);
	}

	for (track = dataGAD.start_track; track <= dataGAD.final_track; track++) {
		memcpy(parmGAT.signature, "CD01", 4);
		parmGAT.track_number = track;
		memset(&dataGAT, 0, sizeof(dataGAT));
		rc = DosDevIOCtl(
			drive, IOCTL_CDROMAUDIO, CDROMAUDIO_GETAUDIOTRACK,
			&parmGAT, ulParmLen = sizeof(parmGAT), &ulParmLen,
			&dataGAT, ulDataLen = sizeof(dataGAT), &ulDataLen
		);
		if (rc) {
			sprintf(errbuf, "Could not get info for track %d: error %ld", track, rc);
			whoops(errbuf);
			exit(1);
		}

		printf(
			"%d\t%d\t%d\t%d\n",
			track,
			dataGAT.track_address.mins,
			dataGAT.track_address.secs,
			dataGAT.track_address.frames
		);
	}
	printf(
		"999\t%d\t%d\t%d\n",
		dataGAD.lead_out_address.mins,
		dataGAD.lead_out_address.secs,
		dataGAD.lead_out_address.frames
	);

	DosClose(drive);

	return(0);
}
