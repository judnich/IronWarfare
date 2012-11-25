// Copyright © 2009 John Judnich. All rights reserved.

#import "Mesh.h"
#import <stdio.h>

int c_main(int argc, const char *argv[]);
int main(int argc, const char *argv[])
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	c_main(argc, argv);
	[autoreleasePool release];
}

int c_main(int argc, const char *argv[])
{
	const char *sourceFile = NULL;
	char destFile[512];
	if (argc == 3) {
		sourceFile = argv[1];
		strcpy(destFile, argv[2]);
	}
	else if (argc == 2) {
		sourceFile = argv[1];
		strcpy(destFile, argv[1]);
		strcat(destFile, ".xmesh");
	}
	
	// for debugging
	//char _sourceFile[512];
	//strcpy(_sourceFile, "/Users/johnjudnich/Documents/BattleTanks/Media/Tanks/MediumTank/mediumtank.obj");
	//strcpy(destFile, "/Users/johnjudnich/Documents/BattleTanks/Media/Tanks/MediumTank/mediumtank.xmesh");
	//sourceFile = _sourceFile;

	if (sourceFile) {
		printf("\n");
		printf("Loading mesh file: \"%s\"...\n", sourceFile);
		Mesh *mesh = [[Mesh alloc] initWithFile:sourceFile];
		if (mesh) {
			printf("Optimizing mesh...\n");
			[mesh optimize];
			printf("Saving to: \"%s\"...\n", destFile);
			if ([mesh saveToFile:destFile]) {
				printf("Conversion complete.\n");
				[mesh release];
			} else {
				[mesh release];
				printf("Error encountered. Conversion aborted.\n");
				return 1;
			}
		} else {
			printf("Error encountered. Conversion aborted.\n");
			return 1;
		}
	}
	else {
		if (argc == 1)
			printf("meshconverter: No input file specified\n\n");
		if (argc > 3)
			printf("meshconverter: Too many parameters provided\n\n");
		printf("Usage: meshconverter source-mesh.obj [converted-output.xmesh]\n");
	}
	printf("\n");
    return 0;
}
