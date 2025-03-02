from libcpp.vector cimport vector
from libcpp.string cimport string

cdef class CythonHomomorphic:

    def __cinit__(self):
        self.homomorphic = new HomomorphicEncryption()
    
    def __dealloc__(self):
        del self.homomorphic 

    cdef initializeCKKS(self, int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize):
        self.homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize)

    cdef setupSchemeSwitching(self,int slots, int logQ_ccLWE):
        self.homomorphic.setupSchemeSwitching(slots, logQ_ccLWE)

    cdef CiphertextDCRTPoly encrypt(self, list plaintext):
        cdef vector[double] plainText
        for value in plaintext:
            plainText.push_back(value)
        cdef CiphertextDCRTPoly cipherText = self.homomorphic.encrypt(plainText)
        return cipherText

    cdef PlaintextDCRTPoly decrypt(self, CiphertextDCRTPoly ciphertext):
        cdef PlaintextDCRTPoly plaintext = self.homomorphic.decrypt(ciphertext)
        return plaintext

    cdef vector[double] compare(self, int slots, CiphertextDCRTPoly ciphertext1, CiphertextDCRTPoly ciphertext2):
        cdef vector[double] result = self.homomorphic.compare(slots, ciphertext1, ciphertext2)
        return result

