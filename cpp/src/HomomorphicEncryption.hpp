#pragma once

#include <iostream>
#include <vector>
#include <filesystem>
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
		void initializeCKKS(int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize, const std::string &filepath);
		void generateRotateKey(int slots);
		void setupSchemeSwitching(int slots, int logQ_ccLWE);
		Ciphertext encrypt(const std::vector<double>& plain);
		Plaintext decrypt(const Ciphertext& ciphertext);
		std::vector<double> compare(int slots, const Ciphertext& cipher1, const Ciphertext& cipher2);
		Ciphertext sumCiphertext(int slots, const Ciphertext &ciphertext);
		Ciphertext maskCiphertext(int slots, const Ciphertext &ciphertext, const Ciphertext &mask);
		std::vector<double> getRealValue(int slots, const Ciphertext &ciphertext);
		void writeCiphertextToFile(const std::string& filepath, const Ciphertext& ciphertext);
		Ciphertext extractSlot(int slots, int index, const Ciphertext &ciphertext);
		std::string serializeToStream(Ciphertext& ciphertext);
		Ciphertext deserializeFromStream(const std::string& serializedData);
		Ciphertext rotateCipher(int index, const Ciphertext& ciphertext);
		void serializeContext(const std::string& filepath);
		void deserializeContext(const std::string& filepath);
		void serializeKeys(const std::string& filepath);
		void deserializeKeys(const std::string& filepath);
		size_t getNumberOfSlots();

	private:
		CryptoContext cryptoContext;
		KeyPair keyPair;
		LWEPrivateKey privateKeyFHEW;  
		std::shared_ptr<BinFHEContext> ccLWE;
	};
}


