#include <jni.h>
#include <Jolt/Jolt.h>
#include <Jolt/Physics/Character/CharacterVirtual.h>

extern "C" JNIEXPORT void JNICALL
Java_com_jasonholtdigital_dart3d_JoltStairWidth_setMinimumWidth(
    JNIEnv *, jobject, jlong characterAddress, jfloat minimumWidth) {
    reinterpret_cast<JPH::CharacterVirtual *>(characterAddress)
        ->SetWalkStairsMinimumWidth(minimumWidth);
}
