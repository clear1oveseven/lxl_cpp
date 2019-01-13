#pragma once
#include <stdint.h>

using NetId = uint64_t;
const static NetId INVALID_NET_ID = 0;

namespace Net
{
	// �������������ֽ���
	static const int PROTOCOL_LEN_DESCRIPT_SIZE = sizeof(uint32_t);
	static const int PROTOCOL_CONTENT_MAX_SIZE = 4096;
	static const int PROTOCOL_MAX_SIZE = PROTOCOL_LEN_DESCRIPT_SIZE + PROTOCOL_CONTENT_MAX_SIZE;
}
