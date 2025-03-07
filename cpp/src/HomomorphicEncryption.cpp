#include "HomomorphicEncryption.hpp"

using namespace Xtore;
using namespace lbcrypto;

namespace Xtore
{
    HomomorphicEncryption::HomomorphicEncryption(){

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

    Ciphertext HomomorphicEncryption::encrypt(const std::vector<double> &plain)
    {
        Plaintext plaintext = cryptoContext->MakeCKKSPackedPlaintext(plain);
        Ciphertext ciphertext = cryptoContext->Encrypt(keyPair.publicKey, plaintext);
        return ciphertext;
    }

    Plaintext HomomorphicEncryption::decrypt(const Ciphertext& ciphertext)
    {
        Plaintext plaintext;
        cryptoContext->Decrypt(keyPair.secretKey, ciphertext, &plaintext);
        return plaintext;
    }

    std::vector<double> HomomorphicEncryption::compare(int slots, const Ciphertext& cipher1, const Ciphertext& cipher2)
    {
        std::vector<double> result(slots);
        Ciphertext cDiff = cryptoContext->EvalSub(cipher1, cipher2);
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

    Ciphertext HomomorphicEncryption::maskCiphertext(int slots, const Ciphertext &ciphertext, const Ciphertext &mask){
        
        // use for test
        auto maskedCiphertext = cryptoContext->EvalMult(ciphertext, mask);
        Plaintext decryptedMasked;
        cryptoContext->Decrypt(keyPair.secretKey, maskedCiphertext, &decryptedMasked);

        decryptedMasked->SetLength(slots);
        for (const auto& val : decryptedMasked->GetRealPackedValue()) {
            std::cout << val << " ";
        }
        std::cout << std::endl;
        // use for test

        return cryptoContext->EvalMult(ciphertext, mask);
    }

    void HomomorphicEncryption::testFunctionHomomorphic(const std::vector<double> &plain){

        // Plaintext plaintext = cryptoContext->MakeCKKSPackedPlaintext(plain);
        // Ciphertext ciphertext = cryptoContext->Encrypt(keyPair.publicKey, plaintext);
        // std::cout << "Ciphertext : "  << std::endl;
        // const char* ciphertextFile = "/home/pings/Senior/test/ciphertext.bin";
        // std::ofstream outFile(ciphertextFile, std::ios::binary);
        // outFile.is_open();
        // Serial::SerializeToFile(ciphertextFile, ciphertext, SerType::BINARY);
        // std::cout << "Ciphertext saved to: " << ciphertextFile << std::endl;
        // outFile.close();

    }
}