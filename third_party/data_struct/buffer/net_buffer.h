#pragma once

#include <stdint.h>

class NetBuffer
{
public:
	NetBuffer(uint32_t init_size, uint32_t step_size);
	NetBuffer(char *buff, uint32_t buff_size, uint32_t step_size);
	~NetBuffer();

	uint32_t LeftSpace();
	uint32_t StepSize();
	uint32_t Capacity();
	char * Ptr();
	uint32_t Pos();
	uint32_t Head();
	char * HeadPtr();
	uint32_t Size();
	void SetPos(uint32_t new_pos);
	void SetHead(uint32_t new_head);
	void AppendBuff(char *buff, uint32_t len);
	void CheckExpend(uint32_t need_capacity);

	template <typename T>
	void Append(T t)
	{
		char *p = (char *)(&t);
		uint32_t len = sizeof(T);
		AppendBuff(p, len);
	}
	uint32_t PopBuff(uint32_t pop_len, char **pop_head);
	bool ResetHead(char *help_buff, uint32_t buff_len); // buff��buff+head֮������ݶ�����buff+head��buff+pos֮��������ƶ���buff��buff+pos-head
	   
private:
	uint32_t m_init_size = 0;
	uint32_t m_step_size = 0;
	char *m_buff = nullptr;
	uint32_t m_head = 0;
	uint32_t m_capacity = 0; // ����
	uint32_t m_pos = 0; // ��д���λ��
};