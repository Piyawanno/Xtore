#pragma once

#include "Buffer.hpp"

namespace Xtore{
	class HomomorphicEncryption{
		public:
			void encrypt(Buffer *plain, Buffer *cipher);
			void decrypt(Buffer *plain, Buffer *cipher);
	}
}