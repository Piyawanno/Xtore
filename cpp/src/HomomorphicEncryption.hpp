#pragma once

#include <openfhe.h>
#include <vector>
#include <iostream>
#include "scheme/ckksrns/ckksrns-schemeswitching.h"

namespace Xtore
{
    typedef lbcrypto::Ciphertext<lbcrypto::DCRTPoly> CiphertextDCRTPoly;
    typedef lbcrypto::Plaintext PlaintextDCRTPoly;

    class HomomorphicEncryption
    {
    public:
        HomomorphicEncryption();
        void initializeCKKS(int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize);
        void setupSchemeSwitching(int slots, int logQ_ccLWE);
        lbcrypto::Ciphertext<lbcrypto::DCRTPoly> encrypt(const std::vector<double>& plain);
        lbcrypto::Plaintext decrypt(lbcrypto::Ciphertext<lbcrypto::DCRTPoly> ciphertext);
        std::vector<double> compare(int slots, lbcrypto::Ciphertext<lbcrypto::DCRTPoly> cipher1, lbcrypto::Ciphertext<lbcrypto::DCRTPoly> cipher2);
    
    public:
        lbcrypto::CryptoContext<lbcrypto::DCRTPoly> cryptoContext;
        CiphertextDCRTPoly ciphertext;
        lbcrypto::KeyPair<lbcrypto::DCRTPoly> keyPair;
        lbcrypto::LWEPrivateKey privateKeyFHEW;  
        std::shared_ptr<lbcrypto::BinFHEContext> ccLWE;
    };
}


