cdef class CythonHomomorphic:

    def __cinit__(self):
        self.homomorphic = new HomomorphicEncryption()
    
    def __dealloc__(self):
        del self.homomorphic 

    cdef initializeCKKS(self, int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize, str filepath):
        cdef string path = filepath.encode("utf-8") 
        self.homomorphic.initializeCKKS(multiplicativeDepth, scalingModSize, firstModSize, ringDim, batchSize, path)
    
    cdef generateRotateKey(self, int slots):
        self.homomorphic.generateRotateKey(slots)

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
    
    cdef vector[double] getRealValue(self, int slots, Ciphertext maskCiphertext):
        return self.homomorphic.getRealValue(slots, maskCiphertext)

    cdef writeCiphertextToFile(self, str filepath, Ciphertext ciphertext):
        cdef string path = filepath.encode("utf-8")  
        self.homomorphic.writeCiphertextToFile(path, ciphertext)

    cdef Ciphertext extractSlot(self, int slots, int index, Ciphertext ciphertext):
        return self.homomorphic.extractSlot(slots, index, ciphertext)

    cdef Ciphertext rotateCipher(self, int index, Ciphertext ciphertext):
        return self.homomorphic.rotateCipher(index, ciphertext)

    cdef string serializeToStream(self, Ciphertext ciphertext):
        cdef string serialized_str = self.homomorphic.serializeToStream(ciphertext)
        return serialized_str

    cdef Ciphertext deserializeFromStream(self, string serializedData):
        return self.homomorphic.deserializeFromStream(serializedData)
    
    cdef serializeKeys(self, str filepath):
        cdef string path = filepath.encode("utf-8")
        self.homomorphic.serializeKeys(path)

    cdef deserializeKeys(self, str filepath):
        cdef string path = filepath.encode("utf-8")
        self.homomorphic.deserializeKeys(path)

    cdef size_t getNumberOfSlots(self):
        return self.homomorphic.getNumberOfSlots()