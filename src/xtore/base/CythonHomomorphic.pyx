cdef class CythonHomomorphic:

    def __cinit__(self):
        self.homomorphic = new HomomorphicEncryption()
    
    def __dealloc__(self):
        del self.homomorphic 

    cdef initializeCKKS(self, int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize):
        self.homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize)

    cdef setupSchemeSwitching(self,int slots, int logQ_ccLWE):
        self.homomorphic.setupSchemeSwitching(slots, logQ_ccLWE)

    cdef Ciphertext encrypt(self, vector[double] plaintext):
        return self.homomorphic.encrypt(plaintext)

    cdef Plaintext decrypt(self, Ciphertext ciphertext):
        return self.homomorphic.decrypt(ciphertext)

    cdef vector[double] compare(self, int slots, Ciphertext ciphertext1, Ciphertext ciphertext2):
        return self.homomorphic.compare(slots, ciphertext1, ciphertext2)

    cdef Ciphertext maskCiphertext(self, int slots, Ciphertext ciphertext, Ciphertext mask):
        return self.homomorphic.maskCiphertext(slots, ciphertext, mask)

    cdef Ciphertext sumCiphertext(self, int slots, Ciphertext ciphertext):
        return self.homomorphic.sumCiphertext(slots, ciphertext)

    cdef testFunctionHomorphic(self, vector[double] plaintext):
        self.homomorphic.testFunctionHomomorphic(plaintext)