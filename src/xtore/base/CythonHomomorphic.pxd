from libcpp.vector cimport vector
from libcpp.string cimport string
# from libcpp cimport lbcrypto

cdef extern from "../../../Xtore/cpp/src/HomomorphicEncryption.hpp" namespace "Xtore":

    cdef cppclass CiphertextDCRTPoly:
        pass
    cdef cppclass PlaintextDCRTPoly:
        pass
        
    cdef cppclass HomomorphicEncryption:
        HomomorphicEncryption() except +
        void initializeCKKS(int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize)
        void setupSchemeSwitching(int slots, int logQ_ccLWE)
        CiphertextDCRTPoly encrypt(const vector[double]& plain) except +
        PlaintextDCRTPoly decrypt(CiphertextDCRTPoly ciphertext) except +
        vector[double] compare(int slots, CiphertextDCRTPoly cipher1, CiphertextDCRTPoly cipher2) except +

cdef class CythonHomomorphic:
    cdef HomomorphicEncryption* homomorphic
    cdef initializeCKKS(self, int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize)
    cdef setupSchemeSwitching(self, int slots, int logQ_ccLWE)
    cdef CiphertextDCRTPoly encrypt(self, list plainText)
    cdef PlaintextDCRTPoly decrypt(self, CiphertextDCRTPoly cipherText)
    cdef vector[double] compare(self, int slots, CiphertextDCRTPoly ciphertext1, CiphertextDCRTPoly ciphertext2)









