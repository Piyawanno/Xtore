#include "HomomorphicEncryption.hpp"
#include <iostream>


using namespace lbcrypto;

namespace Xtore
{
    HomomorphicEncryption::HomomorphicEncryption()
    {
    }

    void HomomorphicEncryption::initializeCKKS(int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize)
    {
        CCParams<CryptoContextCKKSRNS> parameters;
        parameters.SetMultiplicativeDepth(multiplicativeDepth);
        parameters.SetScalingModSize(scalingModSize);
        parameters.SetFirstModSize(firstModSize);
        parameters.SetScalingTechnique(lbcrypto::FLEXIBLEAUTO);
        parameters.SetSecurityLevel(lbcrypto::HEStd_NotSet);
        parameters.SetRingDim(ringDim);
        parameters.SetBatchSize(batchSize);
        parameters.SetSecretKeyDist(lbcrypto::UNIFORM_TERNARY);
        parameters.SetKeySwitchTechnique(lbcrypto::HYBRID);
        parameters.SetNumLargeDigits(3);

        cryptoContext = lbcrypto::GenCryptoContext(parameters);
        
        cryptoContext->Enable(lbcrypto::PKE);
        cryptoContext->Enable(lbcrypto::KEYSWITCH);
        cryptoContext->Enable(lbcrypto::LEVELEDSHE);
        cryptoContext->Enable(lbcrypto::ADVANCEDSHE);
        cryptoContext->Enable(lbcrypto::SCHEMESWITCH);
        
        keyPair = cryptoContext->KeyGen();
    }

    void HomomorphicEncryption::setupSchemeSwitching(int slots, int logQ_ccLWE)
    {
        lbcrypto::SchSwchParams params;
        params.SetSecurityLevelCKKS(lbcrypto::HEStd_NotSet);
        params.SetSecurityLevelFHEW(lbcrypto::TOY);
        params.SetCtxtModSizeFHEWLargePrec(logQ_ccLWE);
        params.SetNumSlotsCKKS(slots);
        params.SetNumValues(slots);

        privateKeyFHEW = cryptoContext->EvalSchemeSwitchingSetup(params);
        ccLWE = cryptoContext->GetBinCCForSchemeSwitch();
        ccLWE->BTKeyGen(privateKeyFHEW);
        cryptoContext->EvalSchemeSwitchingKeyGen(keyPair, privateKeyFHEW);

        auto modulus_LWE     = 1 << logQ_ccLWE;
        auto beta            = ccLWE->GetBeta().ConvertToInt();
        auto pLWE2           = modulus_LWE / (2 * beta);  
        double scaleSignFHEW = 1.0;

        cryptoContext->EvalCompareSwitchPrecompute(pLWE2, scaleSignFHEW);
    }

    Ciphertext<DCRTPoly> HomomorphicEncryption::encrypt(const std::vector<double> &plain)
    {
        auto plaintext = cryptoContext->MakeCKKSPackedPlaintext(plain);
        CiphertextDCRTPoly ciphertext = cryptoContext->Encrypt(keyPair.publicKey, plaintext);
        auto elements = ciphertext->GetElements();
        return ciphertext;
    }

    Plaintext HomomorphicEncryption::decrypt(Ciphertext<DCRTPoly> ciphertext)
    {
        Plaintext plaintext;
        cryptoContext->Decrypt(keyPair.secretKey, ciphertext, &plaintext);
        return plaintext;
    }

    std::vector<double> HomomorphicEncryption::compare(int slots, lbcrypto::Ciphertext<lbcrypto::DCRTPoly> cipher1, lbcrypto::Ciphertext<lbcrypto::DCRTPoly> cipher2) 
    {
        std::vector<double> result(slots);
        auto cDiff = cryptoContext->EvalSub(cipher1, cipher2);
        auto LWECiphertexts = cryptoContext->EvalCKKStoFHEW(cDiff, slots);

        lbcrypto::LWEPlaintext plainLWE;
        int n = LWECiphertexts.size();
        for (int i = 0; i < n; ++i) {
            auto sign = ccLWE->EvalSign(LWECiphertexts[i]);
            ccLWE->Decrypt(privateKeyFHEW, sign, &plainLWE, 2);
            result[i] = plainLWE;
        }
        return result;
    }
}

