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

	std::vector<double> HomomorphicEncryption::compare(int slots, const Ciphertext& ciphertext, const Ciphertext& reference)
	{
		std::vector<double> result(slots);
		Ciphertext cDiff = cryptoContext->EvalSub(ciphertext, reference);
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

	Ciphertext HomomorphicEncryption::maskCiphertext(int slots, const Ciphertext &ciphertext, const Ciphertext &mask)
	{
		return cryptoContext->EvalMult(ciphertext, mask);
	}

	Ciphertext HomomorphicEncryption::sumCiphertext(int slots, const Ciphertext &ciphertext)
	{
		return cryptoContext->EvalSum(ciphertext, slots);
	}

	std::vector<double> HomomorphicEncryption::getMaskValue(int slots, const Ciphertext &maskCiphertext)
	{
		Plaintext decryptedResult;
		cryptoContext->Decrypt(keyPair.secretKey, maskCiphertext, &decryptedResult);
		decryptedResult->SetLength(slots);
		return decryptedResult->GetRealPackedValue();;
	}

	void HomomorphicEncryption::writeCiphertextToFile(const std::string& filepath, const Ciphertext& ciphertext )
	{
		std::ofstream outFile(filepath, std::ios::binary);
		outFile.is_open();
		Serial::SerializeToFile(filepath, ciphertext, SerType::BINARY);
		std::cout << "Ciphertext saved to: " << filepath << std::endl;
		outFile.close();
	}

	Ciphertext HomomorphicEncryption::extractSlot(int slots, int index, const Ciphertext &ciphertext)
	{
			std::vector<double> mask(slots, 0.0);
			mask[index] = 1.0; 
			Plaintext maskPlain = cryptoContext->MakeCKKSPackedPlaintext(mask);

			return cryptoContext->EvalInnerProduct(ciphertext, maskPlain, slots);
	}

	Ciphertext HomomorphicEncryption::rotateCipher(int index, const Ciphertext &ciphertext)
	{
		if (index == 0){
			return ciphertext;
		}
		Ciphertext rotatedCipher = cryptoContext->EvalRotate(ciphertext, index);
		return cryptoContext->ModReduce(rotatedCipher); 
	}
}

