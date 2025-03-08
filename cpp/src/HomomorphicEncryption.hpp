#pragma once

#include <iostream>
#include <vector>
#include "openfhe.h"
#include "DataType.hpp"

namespace Xtore
{
    using DCRTPoly = lbcrypto::DCRTPoly;
    using Ciphertext = lbcrypto::Ciphertext<DCRTPoly>;
    using Plaintext = lbcrypto::Plaintext;
    using CryptoContext = lbcrypto::CryptoContext<DCRTPoly>;
    using KeyPair = lbcrypto::KeyPair<DCRTPoly>;
    using LWEPrivateKey = lbcrypto::LWEPrivateKey;
    using BinFHEContext = lbcrypto::BinFHEContext;

    class HomomorphicEncryption
    {
    public:
        HomomorphicEncryption();
        void initializeCKKS(int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize);
        void setupSchemeSwitching(int slots, int logQ_ccLWE);
        Ciphertext encrypt(const std::vector<double>& plain);
        Plaintext decrypt(const Ciphertext& ciphertext);
        std::vector<double> compare(int slots, const Ciphertext& cipher1, const Ciphertext& cipher2);
        Ciphertext sumCiphertext(int slots, const Ciphertext &ciphertext);
        Ciphertext maskCiphertext(int slots, const Ciphertext &ciphertext, const Ciphertext &mask);
        void testFunctionHomomorphic(const std::vector<double>& plain);

    private:
        CryptoContext cryptoContext;
        KeyPair keyPair;
        LWEPrivateKey privateKeyFHEW;  
        std::shared_ptr<BinFHEContext> ccLWE;
    };
}


