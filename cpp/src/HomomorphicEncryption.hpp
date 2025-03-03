#pragma once

#include <iostream>
#include <vector>
#include "openfhe.h"
#include "DataType.hpp"

namespace Xtore {
	typedef lbcrypto::Ciphertext<lbcrypto::DCRTPoly> CiphertextDCRTPoly;
	typedef lbcrypto::Plaintext PlaintextDCRTPoly;

	class HomomorphicEncryption {
		public:
			HomomorphicEncryption();
			void initializeCKKS(int multiplicativeDepth, int scalingModSize, int firstModSize, int ringDim, int batchSize);
			void setupSchemeSwitching(int slots, int logQ_ccLWE);
			CiphertextDCRTPoly encrypt(const std::vector<double>& plain);
			lbcrypto::Plaintext decrypt(CiphertextDCRTPoly ciphertext);
			std::vector<double> compare(int slots, CiphertextDCRTPoly cipher1, CiphertextDCRTPoly cipher2);
			
		public:
			lbcrypto::CryptoContext<lbcrypto::DCRTPoly> cryptoContext;
			CiphertextDCRTPoly ciphertext;
			lbcrypto::KeyPair<lbcrypto::DCRTPoly> keyPair;
			lbcrypto::LWEPrivateKey privateKeyFHEW;  
			std::shared_ptr<lbcrypto::BinFHEContext> ccLWE;
	};
}


