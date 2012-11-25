// Copyright © 2009 John Judnich. All rights reserved.

#import "Mesh.h"
#import "XMath.h"
#import <stdio.h>

BOOL loadOBJMesh(const char *filename, NSMutableArray *subMeshes);


@implementation Mesh

-(id)initWithFile:(const char*)filename
{
	if ((self = [super init])) {
		subMeshes = [[NSMutableArray alloc] init];
		if (!loadOBJMesh(filename, subMeshes)) {
			[subMeshes release];
			return nil;
		}
	}
	return self;
}

-(void)dealloc
{
	[subMeshes release];
	[super dealloc];
}

-(void)optimize
{
	int oldSubmeshesCount = [subMeshes count];
	
	// merge submeshes with the same texture and untextured submeshes with the same name
	SubMesh *mergeA, *mergeB;
	do {
		mergeA = nil;
		mergeB = nil;
		for (SubMesh *meshA in subMeshes) {
			if (strcmp(meshA->textureFilename, "") == 0) {
				// untextured submesh - merge with submeshes of the same name
				for (SubMesh *meshB in subMeshes) {
					if (meshB != meshA && strcmp(meshA->name, meshB->name) == 0 && (strcmp(meshB->textureFilename, "") == 0)) {
						printf("[Merging extra identically named submesh (\"%s\")]\n", meshA->name);
						mergeA = meshA;
						mergeB = meshB;
						break;
					}
				}
			} else {
				// textured submesh - merge with submeshes of the same texture
				for (SubMesh *meshB in subMeshes) {
					if (meshB != meshA && strcmp(meshA->textureFilename, meshB->textureFilename) == 0) {
						if (strcmp(meshA->name, "") == 0) {
							if (strcmp(meshB->name, "") != 0)
								printf("[Merging extra submesh (\"%s\") sharing the texture \"%s\"]\n", meshB->name, meshA->textureFilename);
							else
								printf("[Merging extra submesh sharing the texture \"%s\"]\n", meshA->textureFilename);
							strcpy(meshA->name, meshB->name);
						} else {
							BOOL printMergedName = NO;
							if (strcmp(meshB->name, "") == 0)
								printf("[Merging extra submesh (\"%s\") sharing the texture \"%s\"]\n", meshA->name, meshA->textureFilename);
							else {
								printf("[Merging two submeshes (\"%s\" and \"%s\") sharing the texture \"%s\". ", meshA->name, meshB->name, meshA->textureFilename);
								printMergedName = YES;
							}
							strcat(meshA->name, ":merged:");
							strcat(meshA->name, meshB->name);
							if (printMergedName)
								printf("Merged name: \"%s\"]\n", meshA->name);
						}
						mergeA = meshA;
						mergeB = meshB;
						break;
					}
				}
			}
			if (mergeA || mergeB)
				break;
		}
		if (mergeA || mergeB) {
			[mergeA appendSubMesh:mergeB];
			[subMeshes removeObject:mergeB];
		}
	} while (mergeA || mergeB);
	
	int newSubmeshesCount = [subMeshes count];
	if (newSubmeshesCount < oldSubmeshesCount)
		printf("(Reduced total number of submeshes from %d to %d)\n", oldSubmeshesCount, newSubmeshesCount);
}

BOOL writeSubMesh(SubMesh *subMesh, FILE *file);

BOOL fwrite2(const void *ptr, size_t size, size_t count, FILE *stream)
{
	if (fwrite(ptr, size, count, stream) != count)
		return NO;
	else return YES;
}

-(BOOL)saveToFile:(const char*)filename
{
	FILE *file = fopen(filename, "wb");
	if (!file) {
		NSLog(@"Error saving XMESH mesh: Could not write output file");
		return NO;
	}
	
	unsigned int numSubMeshes = [subMeshes count];
	if (!fwrite2(&numSubMeshes, sizeof(unsigned int), 1, file))
		return NO;
	
	for (SubMesh *subMesh in subMeshes) {
		if (!writeSubMesh(subMesh, file)) {
			fclose(file);
			NSLog(@"Error saving XMESH mesh: File write error");
			return NO;
		}
	}
	
	fclose(file);
	
	int totalVerts = 0, totalTris = 0;
	for (SubMesh *subMesh in subMeshes) {
		totalVerts += subMesh->meshData.vertexCount;
		totalTris += subMesh->meshData.indexCount / 3;
	}
	printf("Successfully saved [%d total vertexes, %d total triangles]\n", totalVerts, totalTris);
	
	return YES;
}

BOOL writeSubMesh(SubMesh *subMesh, FILE *file)
{
	// write submesh name
	unsigned int nameLen = strlen(subMesh->name);
	if (!fwrite2(&nameLen, sizeof(unsigned int), 1, file)) return NO;
	if (!fwrite2(subMesh->name, sizeof(char), nameLen, file)) return NO;
	// write submesh texture
	unsigned int textureFileLen = strlen(subMesh->textureFilename);
	if (!fwrite2(&textureFileLen, sizeof(unsigned int), 1, file)) return NO;
	if (!fwrite2(subMesh->textureFilename, sizeof(char), textureFileLen, file)) return NO;
	// write bounding box
	if (!fwrite2(&subMesh->meshData.boundingBox, sizeof(XBoundingBox), 1, file)) return NO;
	// write vertex buffer
	if (!fwrite2(&subMesh->meshData.vertexCount, sizeof(unsigned int), 1, file)) return NO;
	if (!fwrite2(subMesh->meshData.vertexBuffer, sizeof(MeshVertex), subMesh->meshData.vertexCount, file)) return NO;
	// write index buffer
	if (!fwrite2(&subMesh->meshData.indexCount, sizeof(unsigned int), 1, file)) return NO;
	if (!fwrite2(subMesh->meshData.indexBuffer, sizeof(MeshIndex), subMesh->meshData.indexCount, file)) return NO;
	return YES;
}

@end


@implementation SubMesh

-(id)initWithName:(const char*)subMeshName defaultTexture:(const char*)filename meshData:(MeshData*)mDat
{
	if ((self = [super init])) {
		strcpy(name, subMeshName);
		strcpy(textureFilename, filename);
		meshData = *mDat;
	}
	return self;
}

-(void)dealloc
{
	assert(meshData.vertexBuffer);
	free(meshData.vertexBuffer);
	assert(meshData.indexBuffer);
	free(meshData.indexBuffer);
	[super dealloc];
}

-(void)appendSubMesh:(SubMesh*)appendMesh
{
	MeshData oldMeshData = meshData;
	
	// merge bounding boxes
	XBoundingBox mergeBB = appendMesh->meshData.boundingBox;
	if (mergeBB.min.x < meshData.boundingBox.min.x) meshData.boundingBox.min.x = mergeBB.min.x;
	else if (mergeBB.max.x > meshData.boundingBox.max.x) meshData.boundingBox.max.x = mergeBB.max.x;
	if (mergeBB.min.y < meshData.boundingBox.min.y) meshData.boundingBox.min.y = mergeBB.min.y;
	else if (mergeBB.max.y > meshData.boundingBox.max.y) meshData.boundingBox.max.y = mergeBB.max.y;
	if (mergeBB.min.z < meshData.boundingBox.min.z) meshData.boundingBox.min.z = mergeBB.min.z;
	else if (mergeBB.max.z > meshData.boundingBox.max.z) meshData.boundingBox.max.z = mergeBB.max.z;
	
	// merge vertex data
	meshData.vertexCount = oldMeshData.vertexCount + appendMesh->meshData.vertexCount;
	meshData.vertexBuffer = malloc(sizeof(MeshVertex) * meshData.vertexCount);
	memcpy(meshData.vertexBuffer, oldMeshData.vertexBuffer, sizeof(MeshVertex) * oldMeshData.vertexCount); //copy old
	memcpy(meshData.vertexBuffer + oldMeshData.vertexCount, //<- copy new into
		   appendMesh->meshData.vertexBuffer, //<- from
		   sizeof(MeshVertex) * appendMesh->meshData.vertexCount); //<- amount
	free(oldMeshData.vertexBuffer);
	
	// merge index data
	meshData.indexCount = oldMeshData.indexCount + appendMesh->meshData.indexCount;
	meshData.indexBuffer = malloc(sizeof(MeshIndex) * meshData.indexCount);
	memcpy(meshData.indexBuffer, oldMeshData.indexBuffer, sizeof(MeshIndex) * oldMeshData.indexCount); //copy old
	// copy new index data, offsetting the indexes to address the appended vertexes
	MeshIndex indexOffset = oldMeshData.vertexCount;
	MeshIndex *outIndexPtr = meshData.indexBuffer + oldMeshData.indexCount;
	for (unsigned int i = 0; i < appendMesh->meshData.indexCount; ++i) {
		outIndexPtr[i] = appendMesh->meshData.indexBuffer[i] + indexOffset;
	}
	free(oldMeshData.indexBuffer);
}

@end


typedef struct {
	unsigned int p[3];
	unsigned int n[3];
	unsigned int t[3];
} ObjTriangle;


MeshData buildSubmeshData(XVector3 *vPositions, int vPositionCount,
						  XVector3 *vNormals, int vNormalCount,
						  XVector2 *vTexcoords, int vTexcoordCount,
						  ObjTriangle *vTriangles, int vTriangleCount);

BOOL loadOBJMesh(const char *filename, NSMutableArray *subMeshes)
{
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	// read contents of file into a buffer
	FILE *file = fopen(filename, "rb");
	if (file == NULL) {
		[autoreleasePool release];
		NSLog(@"File not found.");
		return NO;
	}			
	fseek(file, 0, SEEK_END);
	size_t fileSize = ftell(file);
	rewind(file);
	char *fileContents = (char*)malloc(fileSize);
	if (fileContents == NULL) {
		fclose(file);
		[autoreleasePool release];
		NSLog(@"MEMORY ERROR: Out of memory");
		return NO;
	}
	if (fread(fileContents, fileSize, 1, file) != 1) {
		free(fileContents);
		[autoreleasePool release];
		NSLog(@"READ ERROR: Could not read file");
		return NO;
	}
	fclose(file);
	
	// pre-scan the file and count the number of "v", "vn", "vt", and "f" lines
	int numVPositions = 0, numVNormals = 0, numVTexcoords = 0, numTriangles = 0;
	{
		char *ptr = fileContents;
		char cmd[3];
		int cmdLen = 0;
		for (size_t i = 0; i < fileSize; ++i) {
			char ch = *ptr++;
			if (ch == '\r' || ch == '\n')
				cmdLen = 0;
			else if (ch != ' ')
				cmd[cmdLen++] = ch;
			
			if (ch == ' ') {
				if (cmdLen == 1) {
					if (cmd[0] == 'v')
						++numVPositions;
					else if (cmd[0] == 'f')
						numTriangles += 2; //each "face" could use two triangles (for quads)
				}
				else if (cmdLen == 2) {
					if (cmd[0] == 'v') {
						if (cmd[1] == 'n')
							++numVNormals;
						else if (cmd[1] == 't')
							++numVTexcoords;
					}
				}
			}			
		}
	}
	
	
	// parse each line, accumulating into temporary data arrays
	XVector3 *vPositions = malloc(sizeof(XVector3) * numVPositions); int vPositionI = 0;
	XVector3 *vNormals = malloc(sizeof(XVector3) * numVNormals); int vNormalI = 0;
	XVector2 *vTexcoords = malloc(sizeof(XVector2) * numVTexcoords); int vTexcoordI = 0;
	ObjTriangle *vTriangles = malloc(sizeof(ObjTriangle) * numTriangles); int vTriangleI = 0;
	char currentGroupName[128], currentTextureFile[256];
	strcpy(currentGroupName, ""); strcpy(currentTextureFile, "");
	char lineBuff[256];
	int lineBuffLen = 0;
	char *words[16];
	int wordCount = 0;
	char *ptr = fileContents;
	for (size_t i = 0; i < fileSize; ++i) {
		char ch = *ptr++;
		if (ch == '\r' || ch == '\n') {
			lineBuff[lineBuffLen++] = '\0';
			// split line into "words"
			BOOL commentLine = NO;
			char *start = &lineBuff[0];
			wordCount = 0;
			for (int o = 0; o < lineBuffLen; ++o) {
				if (lineBuff[o] == '#') {
					commentLine = YES;
					break;
				}
				if (lineBuff[o] == ' ' || lineBuff[o] == '\0') {
					lineBuff[o] = '\0';
					if (o > 0)
						if (wordCount < 16) words[wordCount++] = start;
					start = &lineBuff[o+1];
				}
			}
			// process line
			if (!commentLine && wordCount > 0) {
				// vertex data
				if (strcmp(words[0], "v") == 0) {
					// position
					#ifdef DEBUG
					if (wordCount != 1+3) {
						[autoreleasePool release];
						free(vPositions); free(vNormals); free(vTexcoords);	free(vTriangles); free(fileContents);
						NSLog(@"Error loading OBJ mesh: Vertex coordinates must be 3 dimensional");
						return NO;
					}
					#endif
					XVector3 *vec = &vPositions[vPositionI++];
					vec->x = atof((const char*)words[1]);
					vec->y = atof((const char*)words[2]);
					vec->z = atof((const char*)words[3]);
				}
				else if (strcmp(words[0], "vn") == 0) {
					// normal
					#ifdef DEBUG
					if (wordCount != 1+3) {
						[autoreleasePool release];
						free(vPositions); free(vNormals); free(vTexcoords);	free(vTriangles); free(fileContents);
						NSLog(@"Error loading OBJ mesh: Normal vectors must be 3 dimensional");
						return NO;
					}
					#endif
					XVector3 *vec = &vNormals[vNormalI++];
					vec->x = atof((const char*)words[1]);
					vec->y = atof((const char*)words[2]);
					vec->z = atof((const char*)words[3]);
				}
				else if (strcmp(words[0], "vt") == 0) {
					// uv
					#ifdef DEBUG
					if (wordCount != 1+2) {
						[autoreleasePool release];
						free(vPositions); free(vNormals); free(vTexcoords);	free(vTriangles); free(fileContents);
						NSLog(@"Error loading OBJ mesh: US coordinates must be 2 dimensional");
						return NO;
					}
					#endif
					XVector2 *vec = &vTexcoords[vTexcoordI++];
					vec->x = atof((const char*)words[1]);
					vec->y = 1-atof((const char*)words[2]); //OBJ .v coordinate is inverted
				}
				// faces and groups
				else if (strcmp(words[0], "f") == 0) {
					// triangle or quad
					if (wordCount <= 1+4) {
						// split words into index values
						char *indexVals[3*4];
						int indexValCount = 0;
						for (int w = 1; w < wordCount; ++w) {
							int o = 0, indexes = 0;
							char *start = &(words[w][o]);
							while (1) {
								char ch = words[w][o];
								if (ch == '\\' || ch == '/' || ch == '\0') {
									words[w][o] = '\0';
									if (o > 0) {
										if (indexValCount < 3*4) indexVals[indexValCount++] = start;
										++indexes;
									}
									if (ch == '\0')
										break;
									start = &(words[w][o+1]);
								}
								++o;
							}
							if (indexes != 3) {
								[autoreleasePool release];
								free(vPositions); free(vNormals); free(vTexcoords);	free(vTriangles); free(fileContents);
								NSLog(@"Error loading OBJ mesh: Each face index must have three references (position/UV/normal)");
								return NO;
							}
							
						}
						
						// triangle
						if (wordCount == 1+3) {
							ObjTriangle *tri = &vTriangles[vTriangleI++];
							tri->p[0] = atoi((const char*)indexVals[0])-1;
							tri->t[0] = atoi((const char*)indexVals[1])-1;
							tri->n[0] = atoi((const char*)indexVals[2])-1;
							tri->p[1] = atoi((const char*)indexVals[3])-1;
							tri->t[1] = atoi((const char*)indexVals[4])-1;
							tri->n[1] = atoi((const char*)indexVals[5])-1;
							tri->p[2] = atoi((const char*)indexVals[6])-1;
							tri->t[2] = atoi((const char*)indexVals[7])-1;
							tri->n[2] = atoi((const char*)indexVals[8])-1;
						}
						// quad
						else if (wordCount == 1+4) {
							ObjTriangle *tri = &vTriangles[vTriangleI++];
							tri->p[0] = atoi((const char*)indexVals[0])-1;
							tri->t[0] = atoi((const char*)indexVals[1])-1;
							tri->n[0] = atoi((const char*)indexVals[2])-1;
							tri->p[1] = atoi((const char*)indexVals[3])-1;
							tri->t[1] = atoi((const char*)indexVals[4])-1;
							tri->n[1] = atoi((const char*)indexVals[5])-1;
							tri->p[2] = atoi((const char*)indexVals[6])-1;
							tri->t[2] = atoi((const char*)indexVals[7])-1;
							tri->n[2] = atoi((const char*)indexVals[8])-1;
							tri = &vTriangles[vTriangleI++];
							tri->p[0] = atoi((const char*)indexVals[0])-1;
							tri->t[0] = atoi((const char*)indexVals[1])-1;
							tri->n[0] = atoi((const char*)indexVals[2])-1;
							tri->p[1] = atoi((const char*)indexVals[6])-1;
							tri->t[1] = atoi((const char*)indexVals[7])-1;
							tri->n[1] = atoi((const char*)indexVals[8])-1;
							tri->p[2] = atoi((const char*)indexVals[9])-1;
							tri->t[2] = atoi((const char*)indexVals[10])-1;
							tri->n[2] = atoi((const char*)indexVals[11])-1;
						}
					}
					else {
						[autoreleasePool release];
						free(vPositions); free(vNormals); free(vTexcoords);	free(vTriangles); free(fileContents);
						NSLog(@"Error loading OBJ mesh: Only triangle and quad faces (3-4 vertexes per face) are supported by OBJ loader");
						return NO;
					}
				}
				else {
					BOOL newGroup = (strcmp(words[0], "g") == 0);
					BOOL newTex = (strcmp(words[0], "usemtl") == 0);
					if (newGroup || newTex) {
						// a new group or material is being set - finalize the old group into a submesh
						if (vTriangleI > 0) {
							MeshData meshData = buildSubmeshData(vPositions, vPositionI, vNormals, vNormalI, vTexcoords, vTexcoordI, vTriangles, vTriangleI);
							SubMesh *subMesh = [[SubMesh alloc] initWithName:currentGroupName defaultTexture:currentTextureFile meshData:&meshData];
							[subMeshes addObject:subMesh];
							[subMesh release];
							vTriangleI = 0;
						}
						
						if (newGroup) {
							// group name
							assert(wordCount == 2);
							strcpy(currentGroupName, words[1]);
						}
						else if (newTex) {
							// material name
							assert(wordCount == 2);
							strcpy(currentTextureFile, words[1]);
						}
					}
				}
			}
			lineBuffLen = 0;
		} else {
			lineBuff[lineBuffLen++] = ch;
		}
	}
	// finalize the old group into a submesh
	if (vTriangleI > 0) {
		MeshData meshData = buildSubmeshData(vPositions, vPositionI, vNormals, vNormalI, vTexcoords, vTexcoordI, vTriangles, vTriangleI);
		SubMesh *subMesh = [[SubMesh alloc] initWithName:currentGroupName defaultTexture:currentTextureFile meshData:&meshData];
		[subMeshes addObject:subMesh];
		[subMesh release];
		vTriangleI = 0;
	}
	
	free(vPositions);
	free(vNormals);
	free(vTexcoords);
	free(vTriangles);
	free(fileContents);
	
	[autoreleasePool release];
	return YES;
}


#define POSITION_EPSILON	0.00005f
#define NORMAL_EPSILON		0.000001f
#define TEXCOORD_EPSILON	0.000001f

MeshData buildSubmeshData(XVector3 *vPositions, int vPositionCount,
						  XVector3 *vNormals, int vNormalCount,
						  XVector2 *vTexcoords, int vTexcoordCount,
						  ObjTriangle *vTriangles, int vTriangleCount)
{
	MeshData meshData;
	
	// allocate arrays for the vertex and index buffer data
	int maxGLVertexes = vTriangleCount * 3;
	int maxGLIndexes = vTriangleCount * 3;
	if (vNormalCount > maxGLIndexes) maxGLIndexes = vNormalCount;
	if (vTexcoordCount > maxGLIndexes) maxGLIndexes = vTexcoordCount;
	MeshVertex *glVertexes = malloc(sizeof(MeshVertex) * maxGLVertexes);
	MeshIndex *glIndexes = malloc(sizeof(MeshIndex) * maxGLIndexes);
	
	// prepare bounding box
	XBoundingBox *bounds = &meshData.boundingBox;
	if (vPositionCount > 0) {
		bounds->min.x = vPositions[0].x;
		bounds->min.y = vPositions[0].y;
		bounds->min.x = vPositions[0].z;
		bounds->max.x = vPositions[0].x;
		bounds->max.y = vPositions[0].y;
		bounds->max.x = vPositions[0].z;
	}
	
	// process each triangle from the OBJ mesh, generating vertexes and indexes for OpenGL
	int glVertexCount = 0, glIndexCount = 0;
	for (int t = 0; t < vTriangleCount; ++t) {
		ObjTriangle *tri = &vTriangles[t];
		// process each vertex of triangle
		for (int v = 0; v < 3; ++v) {
			// get required position/normal/texcoord for this vertex
			XVector3 *pos = &vPositions[tri->p[v]];
			XVector3 *nrm = &vNormals[tri->n[v]];
			XVector2 *tex = &vTexcoords[tri->t[v]];
			// scan current GLVertex array to see if an existing vertex of the required position/normal/texcoord exists
			int glVertexIndex = -1;
			for (int glv = 0; glv < glVertexCount; ++glv) {
				MeshVertex *glVert = &glVertexes[glv];
				if (xIsEqual_Vec3(&glVert->position, pos, POSITION_EPSILON) &&
					xIsEqual_Vec3(&glVert->normal, nrm, NORMAL_EPSILON) &&
					xIsEqual_Vec2(&glVert->texcoord, tex, TEXCOORD_EPSILON)) {
					glVertexIndex = glv;
					break;
				}
			}
			// if no existing vertex was found, create it in the vertex buffer
			if (glVertexIndex == -1) {
				MeshVertex glVertexData;
				glVertexData.position = *pos;
				glVertexData.normal = *nrm;
				glVertexData.texcoord = *tex;
				glVertexIndex = glVertexCount++;
				glVertexes[glVertexIndex] = glVertexData;
				assert(glVertexCount <= maxGLVertexes);
				
				// update bounding box
				if (pos->x < bounds->min.x) bounds->min.x = pos->x;
				else if (pos->x > bounds->max.x) bounds->max.x = pos->x;
				if (pos->y < bounds->min.y) bounds->min.y = pos->y;
				else if (pos->y > bounds->max.y) bounds->max.y = pos->y;
				if (pos->z < bounds->min.z) bounds->min.z = pos->z;
				else if (pos->z > bounds->max.z) bounds->max.z = pos->z;
			}
			// add this triangle's vertex's index to the index buffer
			glIndexes[glIndexCount++] = glVertexIndex;
			assert(glIndexCount <= maxGLIndexes);
		}
	}
	
	meshData.indexCount = glIndexCount;
	meshData.indexBuffer = glIndexes;
	
	meshData.vertexCount = glVertexCount;
	meshData.vertexBuffer = glVertexes;
	
	return meshData;
}


