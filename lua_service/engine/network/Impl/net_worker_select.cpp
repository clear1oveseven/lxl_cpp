#include "net_worker_select.h"
#include <fcntl.h>
#ifdef WIN32
#include <winsock2.h>
#else
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

#ifdef WIN32
#include <winsock2.h>
#define close closesocket
#define read(p1, p2, p3) recv(p1, p2, p3, 0)
#define write(p1, p2, p3) send(p1, p2, p3, 0)
#endif

#ifndef WIN32
static int GetLastError()
{
	return errno;
}
#endif

static bool IsFdUnready(int error_num)
{
	bool ret = false;
#ifndef WIN32
	if (EWOULDBLOCK == error_num || EAGAIN == error_num)
	{
		ret = true;
	}
#else
	if (WSAEWOULDBLOCK == error_num)
	{
		ret = true;
	}
#endif // !WIN32
	return ret;
}

#include "iengine.h"

namespace Net
{
	NetWorkerSelect::NetWorkerSelect()
	{
	}

	NetWorkerSelect::~NetWorkerSelect()
	{
		this->Stop();
	}

	bool NetWorkerSelect::AddCnn(NetId id, int fd, std::shared_ptr<INetworkHandler> handler)
	{
		if (fd < 0)
			return false;

		bool ret = false;
		do 
		{
			if (m_is_exits)
				break;
			if (nullptr == handler)
				break;

			int ret_int = this->MakeFdUnblock(fd);
			if (0 != ret_int)
			{
				// TODO: USE REAL LOG
				printf("MakeFdUnblock fail netid:%I64u, fd:%d, ret_int:%d, errno:%d", id, fd, ret_int, GetLastError());
				break;
			}
			m_new_nodes_mutex.lock();
			if (m_new_nodes.count(id) <= 0)
			{
				ret = true;
				Node *node = new Node();
				node->netid = id;
				node->handler = handler;
				node->fd = fd;
				node->handler_type = handler->HandlerType();
				m_new_nodes.insert(std::make_pair(id, node));
			}
			m_new_nodes_mutex.unlock();
			handler->SetNetId(id);

			ret = true;
		} while (false);
		if (!ret)
		{
			close(fd);
		}
		return ret;
	}

	void NetWorkerSelect::RemoveCnn(NetId id)
	{
		m_to_remove_netids_mutex.lock();
		m_to_remove_netids.insert(id);
		m_to_remove_netids_mutex.unlock();
	}

	bool NetWorkerSelect::Send(NetId netId, const char * buffer, uint32_t len)
	{
		if (m_is_exits)
			return false;

		if (nullptr == buffer || len <= 0)
			return false;

		m_wait_send_buffs_mutex.lock();
		auto it = m_wait_send_buffs.find(netId);
		if (m_wait_send_buffs.end() == it)
		{
			NetBuffer *buff = new NetBuffer(64, 64, nullptr, nullptr, nullptr);
			auto ret = m_wait_send_buffs.insert(std::make_pair(netId, buff));
			if (!ret.second)
			{
				delete buff; buff = nullptr;
				return false;
			}
			it = ret.first;
		}
		NetBuffer *buff = it->second;
		buff->AppendBuff(buffer, len);
		m_wait_send_buffs_mutex.unlock();
		return true;
	}

	bool NetWorkerSelect::GetNetDatas(std::queue<NetworkData*>** out_datas)
	{
		if (nullptr == out_datas)
			return false;

		m_net_datas_mutex.lock();
		*out_datas = &m_net_datas[m_net_datas_using_idx];
		m_net_datas_using_idx = (m_net_datas_using_idx + 1) % Net_Data_Queue_Size;
		m_net_datas_mutex.unlock();
		return true;
	}

	bool NetWorkerSelect::Start()
	{
		if (m_is_started || nullptr != m_work_thread)
			return false;

		m_work_thread = new std::thread(std::bind(&NetWorkerSelect::WorkLoop, this));
		m_is_started = true;
		return true;
	}

	void NetWorkerSelect::Stop()
	{
		m_is_exits = true;
		if (nullptr != m_work_thread)
		{
			if (m_work_thread->joinable())
			{
				m_work_thread->join();
			}
			delete m_work_thread; m_work_thread = nullptr;
		}

		// ���ж�������������һ��

	}

	void NetWorkerSelect::WorkLoop()
	{
		const int MS_PER_LOOP = 10;
		int max_fd = -1;
		fd_set read_set, write_set, error_set;
		timeval timeout_tv;

		int loop_times = 0;
		while (!this->m_is_exits)
		{
			WorkLoop_AddConn();
			WorkLoop_SendBuff();
			{
				max_fd = -1;
				FD_ZERO(&read_set);
				FD_ZERO(&write_set);
				FD_ZERO(&error_set);

				// ����fd_set
				if (!this->m_id2nodes.empty())
				{
					// ��Ϊfd_set�Ĵ�С���ޣ������ַ�ʽʹ�����е�fd���л��ᱻ����
					auto it = m_id2nodes.begin();
					if (m_next_it_advance < m_id2nodes.size())
					{
						std::advance(it, m_next_it_advance);
					}
					else
					{
						m_next_it_advance = 0;
					}
					uint64_t read_set_count = 0;
					for (; this->m_id2nodes.end() != it; ++it)
					{
						++m_next_it_advance;
						Node *node = it->second;
						if (node->closed || node->fd < 0)
							continue;

						FD_SET(node->fd, &read_set);
						FD_SET(node->fd, &error_set);
						if (!node->send_buffs.empty())
						{
							FD_SET(node->fd, &write_set);
						}
						if (node->fd > max_fd)
						{
							max_fd = node->fd;
						}
						++read_set_count;
						if (read_set_count >= FD_SETSIZE)
						{
							break;
						}
					}
					/*
					{
						if (m_id2nodes.end() == it)
						{
							m_next_it_advance = 0;
						}
						log_debug("select work max fd:{}, count:{}, fd_array_size:{}, read_set_count:{}, m_next_it_advance:{}",
							max_fd, m_id2nodes.size(), FD_SETSIZE, read_set_count, m_next_it_advance);
					}
					*/
				}
			}
			timeout_tv.tv_sec = 0;
			timeout_tv.tv_usec = MS_PER_LOOP * 1000; // 50����
			int ret = select(max_fd + 1, &read_set, &write_set, nullptr, &timeout_tv) > 0;
			if (ret > 0)
			{
				int hited_count = 0;
				for (int i = 0; i <= max_fd; ++ i)
				{
					bool hited = false;
					if (FD_ISSET(i, &read_set))
					{
						hited = true;
						this->HandleNetRead(i);
					}
					if (FD_ISSET(i, &write_set))
					{
						this->HandleNetWrite(i);
						hited = true;
					}
					if (hited)
					{
						++hited_count;
						if (hited_count > ret)
						{
							// break;
						}
					}
				}
				// log_debug("select worker ret:{}, hit times:{}", ret, hited_count);
			}
			WorkLoop_RemoveConn();

			// �������sleep����ô�߳̾��޷�join���������Ϊʲô debian9��������
			if (ret <= 0)
			{
				std::this_thread::sleep_for(std::chrono::milliseconds(MS_PER_LOOP));
			}
			
		}
		this->m_to_remove_netids_mutex.lock();
		if (!this->m_id2nodes.empty())
		for (auto kv : this->m_id2nodes)
		{
			this->m_to_remove_netids.insert(kv.first);
		}
		this->m_to_remove_netids_mutex.unlock();
		WorkLoop_AddConn();
		WorkLoop_RemoveConn();
		WorkLoop_SendBuff();
	}

	void NetWorkerSelect::WorkLoop_AddConn()
	{
		// ����ڵ�
		if (!this->m_new_nodes.empty())
		{
			this->m_new_nodes_mutex.lock();
			std::unordered_map<NetId, Node *> new_nodes; new_nodes.swap(this->m_new_nodes);
			this->m_new_nodes_mutex.unlock();

			for (auto kv : new_nodes)
			{
				this->m_id2nodes.insert(kv);
			}
		}
	}

	void NetWorkerSelect::WorkLoop_RemoveConn()
	{
		// ɾ���ڵ�
		if (!this->m_to_remove_netids.empty())
		{
			this->m_to_remove_netids_mutex.lock();
			std::set<NetId> to_remove_netids; to_remove_netids.swap(this->m_to_remove_netids);
			this->m_to_remove_netids_mutex.unlock();
			std::set<NetId> delay_remove_netids;

			for (auto netid : to_remove_netids)
			{
				bool is_remove = true;
				auto node_it = this->m_id2nodes.find(netid);
				if (node_it != this->m_id2nodes.end())
				{
					Node *node = node_it->second;
					bool need_send = false;
					if (!node->closed && node->fd >= 0)
					{
						if (!node->send_buffs.empty())
						{
							need_send = true;
						}
						else
						{
							this->m_wait_send_buffs_mutex.lock();
							auto it = this->m_wait_send_buffs.find(netid);
							if (this->m_wait_send_buffs.end() != it)
							{
								need_send = true;
							}
							this->m_wait_send_buffs_mutex.unlock();
						}
					}
					if (need_send)
					{
						is_remove = false;
						delay_remove_netids.insert(netid);
					}
					else
					{
						this->m_id2nodes.erase(node_it);
						node_it = this->m_id2nodes.end();
						if (!node->closed && node->fd >= 0)
						{
							node->closed = true;
							close(node->fd);
							node->fd = -1;
						}
						NetworkData *network_data = new NetworkData(node->handler_type,
							node->netid, node->fd, node->handler, ENetWorkDataAction_Close,
							0, -1, nullptr);
						this->AddNetworkData(network_data);
						Node::DestroyNode(node); node = nullptr;
					}
				}
				if (is_remove)
				{
					this->m_wait_send_buffs_mutex.lock();
					auto it = this->m_wait_send_buffs.find(netid);
					if (this->m_wait_send_buffs.end() != it)
					{
						delete it->second;
						this->m_wait_send_buffs.erase(it);
					}
					this->m_wait_send_buffs_mutex.unlock();
				}
			}
			if (!delay_remove_netids.empty())
			{
				this->m_to_remove_netids_mutex.lock();
				this->m_to_remove_netids.insert(delay_remove_netids.begin(), delay_remove_netids.end());
				this->m_to_remove_netids_mutex.unlock();
			}
		}
	}

	void NetWorkerSelect::WorkLoop_SendBuff()
	{
		// ����Ҫ�����͵�NetBuffer
		if (!this->m_wait_send_buffs.empty())
		{
			this->m_wait_send_buffs_mutex.lock();
			std::unordered_map<NetId, NetBuffer *> wait_send_buffs; wait_send_buffs.swap(this->m_wait_send_buffs);
			this->m_wait_send_buffs_mutex.unlock();

			for (auto kv : wait_send_buffs)
			{
				auto it = this->m_id2nodes.find(kv.first);
				if (this->m_id2nodes.end() == it || ENetworkHandler_Connect != it->second->handler_type)
				{
					delete kv.second;
				}
				else
				{
					it->second->AddSendBuff(kv.second);
				}
			}
		}
	}

	void NetWorkerSelect::HandleNetRead(int fd)
	{
		Node *node = this->GetNodeByFd(fd);
		if (nullptr == node)
			return;

		if (ENetworkHandler_Connect == node->handler_type)
		{
			NetBuffer *buff = new NetBuffer(64, 64, nullptr, nullptr, nullptr);
			int read_len = 0;
			int error_num = 0;
			bool close_fd = false;
			while (true)
			{
				if (buff->LeftSpace() <= 0)
				{
					buff->CheckExpend(buff->Capacity() + buff->StepSize());
				}
				int read_len = read(node->fd, buff->Ptr(), buff->LeftSpace());
				if (read_len > 0)
				{
					buff->SetPos(buff->Pos() + read_len);
				}
				if (0 == read_len)
				{
					close_fd = true;
					error_num = Net::ERROR_PEER_CLOSED;
					break;
				}
				if (read_len < 0)
				{
					error_num = GetLastError();
					if (!IsFdUnready(error_num))
					{
						close_fd = true;
					}
					break;
				}
			}
			if (buff->Size() > 0)
			{
				this->AddNetworkData(new NetworkData(
					node->handler_type,
					node->netid,
					node->fd,
					node->handler,
					ENetWorkDataAction_Read,
					0, 0, buff
				));
			}
			else
			{
				delete buff; buff = nullptr;
			}
			if (close_fd)
			{
				HandleNetError(fd, error_num);
			}
		}
		if (ENetworkHandler_Listen == node->handler_type)
		{
			int new_fd = accept(fd, nullptr, nullptr);
			int error_no = GetLastError();
			if (new_fd >= 0)
			{
				this->AddNetworkData(new NetworkData(
					node->handler_type,
					node->netid,
					node->fd,
					node->handler,
					ENetWorkDataAction_Read,
					0, new_fd, nullptr
				));
			}
		}
	}

	void NetWorkerSelect::HandleNetWrite(int fd)
	{
		Node *node = this->GetNodeByFd(fd);
		if (nullptr == node)
			return;

		if (ENetworkHandler_Connect == node->handler_type)
		{
			int error_num = 0;
			bool close_fd = false;
			while (!node->send_buffs.empty())
			{
				NetBuffer *buff = node->send_buffs.front();
				if (buff->Size() > 0)
				{
					uint32_t buf_size = buff->Size();
					char *p = buff->HeadPtr();
					int write_len = write(node->fd, p, buf_size);
					if (write_len > 0)
					{
						buff->PopBuff(write_len, nullptr);
					}
					if (0 == write_len)
					{
						close_fd = true;
						error_num = Net::ERROR_WRITE_CLOSED_SOCKET;
						break;
					}
					if (write_len < 0)
					{
						error_num = GetLastError();
						if (!IsFdUnready(error_num))
						{
							close_fd = true;
							break;
						}
					}
				}
				if (buff->Size() <= 0)
				{
					node->send_buffs.pop();
					delete buff;
				}
			}
			if (close_fd)
			{
				HandleNetError(fd, error_num);
			}
		}
	}

	void NetWorkerSelect::HandleNetError(int fd, int error_num)
	{
		if (fd >= 0)
		{
			close(fd);
		}
		Node *node = this->GetNodeByFd(fd);
		if (nullptr == node)
		{
			return;
		}
		m_id2nodes.erase(node->netid);
		this->AddNetworkData(new NetworkData(
			node->handler_type,
			node->netid,
			node->fd,
			node->handler,
			ENetWorkDataAction_Close,
			error_num, 0, nullptr
		));
		Node::DestroyNode(node); node = nullptr;
	}

	NetWorkerSelect::Node * NetWorkerSelect::GetNodeByFd(int fd)
	{
		// TODO: �Ż�
		for (auto kv : m_id2nodes)
		{
			if (kv.second->fd == fd)
			{
				return kv.second;
			}
		}
		return nullptr;
	}

	void NetWorkerSelect::AddNetworkData(NetworkData * data)
	{
		m_net_datas_mutex.lock();
		m_net_datas[m_net_datas_using_idx].push(data);
		m_net_datas_mutex.unlock();
	}

	int NetWorkerSelect::MakeFdUnblock(int fd)
	{
		int ret;
#ifdef WIN32
		unsigned long b = 1;
		ret = ioctlsocket((SOCKET)fd, FIONBIO, &b);
#else
		int flag = fcntl(fd, F_GETFL, 0) | O_NONBLOCK;
		ret = fcntl(fd, F_SETFL, flag);
#endif
		return ret;
	}

	void NetWorkerSelect::Node::AddSendBuff(NetBuffer *net_buffer)
	{
		// TODO: �Ż�
		send_buffs.push(net_buffer);
	}
	void NetWorkerSelect::Node::DestroyNode(Node * node)
	{
		if (nullptr == node) 
			return;

		while (!node->send_buffs.empty())
		{
			delete node->send_buffs.front();
			node->send_buffs.pop();
		}
		delete node; node = nullptr;
	}
}