from xtore.BaseType cimport i32, i64, f32
from openfhe import (
	CCParamsCKKSRNS, 
	GenCryptoContext, 
	SchSwchParams, 
	FIXEDAUTO, 
	HEStd_NotSet, 
	UNIFORM_TERNARY, 
	HYBRID, 
	PKE, 
	KEYSWITCH, 
	LEVELEDSHE, 
	ADVANCEDSHE, 
	SCHEMESWITCH, 
	TOY,
	Plaintext,	
)

cdef class Homomorphic():
	cdef createCKKS(self, i32 multDepth, i32 scaleModSize, i32 firstModSize, i32 ringDim, i32 batchSize):
		cdef object parameters = CCParamsCKKSRNS()

		parameters.SetMultiplicativeDepth(multDepth)
		parameters.SetScalingModSize(scaleModSize)
		parameters.SetFirstModSize(firstModSize)
		parameters.SetScalingTechnique(FIXEDAUTO)
		parameters.SetSecurityLevel(HEStd_NotSet)
		parameters.SetRingDim(ringDim)
		parameters.SetBatchSize(batchSize)
		parameters.SetSecretKeyDist(UNIFORM_TERNARY)
		parameters.SetKeySwitchTechnique(HYBRID)
		parameters.SetNumLargeDigits(3)

		self.cc = GenCryptoContext(parameters)
		self.cc.Enable(PKE)
		self.cc.Enable(KEYSWITCH)
		self.cc.Enable(LEVELEDSHE)
		self.cc.Enable(ADVANCEDSHE)
		self.cc.Enable(SCHEMESWITCH)

		self.keys =  self.cc.KeyGen()

	cdef createFHEW(self, i32 logQ_ccLWE, i32 slots):
		cdef i64 pLWE1
		cdef i64 pLWE2
		cdef i64 modulus_LWE
		cdef f32 beta
		cdef f32 scaleSignFHEW
		cdef object params = SchSwchParams()
		params.SetSecurityLevelCKKS(HEStd_NotSet)
		params.SetSecurityLevelFHEW(TOY)
		params.SetCtxtModSizeFHEWLargePrec(logQ_ccLWE)
		params.SetNumSlotsCKKS(slots)
		params.SetNumValues(slots)

		self.privateKeyFHEW = self.cc.EvalSchemeSwitchingSetup(params)
		self.ccLWE = self.cc.GetBinCCForSchemeSwitch()
		self.cc.EvalSchemeSwitchingKeyGen(self.keys, self.privateKeyFHEW)

		pLWE1 = self.ccLWE.GetMaxPlaintextSpace()
		modulus_LWE = 1 << logQ_ccLWE
		beta =  self.ccLWE.GetBeta()
		pLWE2 = int(modulus_LWE / (2 * beta))
		scaleSignFHEW = 1.0
		self.cc.EvalCompareSwitchPrecompute(pLWE2, scaleSignFHEW)

	cdef object encrypt(self, object ptxt):
		cdef object plaintext = self.cc.MakeCKKSPackedPlaintext([ptxt])
		return  self.cc.Encrypt(self.keys.publicKey, plaintext)

	cdef f32 decrypt(self, object ctxt):
		plainLWE = self.cc.Decrypt(self.keys.secretKey, ctxt)
		cdef list dcryptedValues = Plaintext.GetRealPackedValue(plainLWE)
		return dcryptedValues[0]

	cdef object diff(self, object c1, object c2):
		return  self.cc.EvalSub(c1, c2)

	cdef object getSign(self, object cDiff):
		cdef object LWECiphertexts = self.cc.EvalCKKStoFHEW(cDiff)
		cdef object LWESign = [None] * len(LWECiphertexts)
		cdef object plainLWE
		for i in range(len(LWECiphertexts)):
			LWESign[i] = self.ccLWE.EvalSign(LWECiphertexts[i])
			plainLWE = self.ccLWE.Decrypt(self.privateKeyFHEW, LWESign[i], 2)
		return plainLWE

		