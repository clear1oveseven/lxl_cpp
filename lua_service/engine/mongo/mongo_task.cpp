#include "mongo_task.h"
#include <mongocxx/exception/exception.hpp>
#include <iengine.h>

MongoTask::MongoTask(eMongoTask task_type, const std::string & db_name, const std::string & coll_name, const bsoncxx::document::view_or_value & filter, const bsoncxx::document::view_or_value & content, const bsoncxx::document::view_or_value & opt, ResultCbFn cb_fn)
{
	m_task_type = task_type;
	m_db_name = db_name;
	m_coll_name = coll_name;
	m_filter = new bsoncxx::document::value(filter);
	m_opt = new bsoncxx::document::value(opt);
	m_content = new bsoncxx::document::value(content);
	m_cb_fn = cb_fn;
	m_state = eMongoTaskState_Ready;
}

MongoTask::MongoTask(eMongoTask task_type, const std::string & db_name, const std::string & coll_name, const bsoncxx::document::view_or_value & filter, const std::vector<bsoncxx::document::view_or_value>& contents, const bsoncxx::document::view_or_value & opt, ResultCbFn cb_fn)
{
}

MongoTask::~MongoTask()
{
	delete m_filter; m_filter = nullptr;
	delete m_opt; m_opt = nullptr;
	delete m_content; m_content = nullptr;
}

#include <mongocxx/client.hpp>
#include <mongocxx/database.hpp>
#include <mongocxx/uri.hpp>
#include <mongocxx/instance.hpp>
#include <bsoncxx/builder/stream/document.hpp>
#include <bsoncxx/oid.hpp>

void MongoTask::Process(mongocxx::client & client)
{
	try
	{
		m_state = eMongoTaskState_Processing;
		switch (m_task_type)
		{
		case eMongoTask_FindOne:
			DoTask_FindOne(client);
			break;
		case eMongoTask_FindMany:
			DoTask_FindMany(client);
			break;
		case eMongoTask_InsertOne:
			DoTask_InsertOne(client);
			break;
		case eMongoTask_InsertMany:
			break;
		case eMongoTask_UpdateOne:
			DoTask_UpdateOne(client);
			break;
		case eMongoTask_UpdateMany:
			break;
		case eMongoTask_DeleteOne:
			DoTask_DeleteOne(client);
			break;
		case eMongoTask_DeleteMany:
			break;
		case eMongoTask_Count:
			break;
		case eMongoTask_ReplaceOne:
			DoTask_ReplaceOne(client);
			break;
		case eMongoTask_ReplaceMany:
			break;
		default:
			break;
		}
	}
	catch (mongocxx::exception & ex)
	{
		m_err_num = ex.code().value();
		m_err_msg = ex.what();
		log_error("MongoTask::Process fail {} {}", m_err_num, m_err_msg);
	}	
	m_state = eMongoTaskState_Done;
}

void MongoTask::HandleResult()
{
	if (nullptr != m_cb_fn)
	{
		m_cb_fn(this);
	}
}

mongocxx::collection MongoTask::GetColl(mongocxx::client & client)
{
	mongocxx::database db = client.database(m_db_name);
	mongocxx::collection coll = db.collection(m_coll_name);
	return coll;
}

mongocxx::options::find MongoTask::GenFindOpt(bsoncxx::document::view & view)
{
	return mongocxx::options::find();
}

mongocxx::options::insert MongoTask::GenInsertOpt(bsoncxx::document::view & view)
{
	return mongocxx::options::insert();
}

mongocxx::options::delete_options MongoTask::GenDeleteOpt(bsoncxx::document::view & view)
{
	return mongocxx::options::delete_options();
}

mongocxx::options::update MongoTask::GenUpdateOpt(bsoncxx::document::view & view)
{
	return mongocxx::options::update();
}

void MongoTask::DoTask_FindOne(mongocxx::client & client)
{
	mongocxx::collection coll = this->GetColl(client);
	mongocxx::options::find opt = GenFindOpt(m_opt->view());
	bsoncxx::builder::basic::array builder;
	boost::optional<bsoncxx::document::value> ret = coll.find_one(m_filter->view(), opt);
	if (ret)
	{
		m_result.matched_count = 1;
		builder.append(std::move(bsoncxx::document::value(*ret)));
	}
	m_result.val = new bsoncxx::document::value(builder.view());
}

void MongoTask::DoTask_FindMany(mongocxx::client & client)
{
	mongocxx::collection coll = this->GetColl(client);
	mongocxx::options::find opt = GenFindOpt(m_opt->view());
	mongocxx::cursor ret = coll.find(m_filter->view(), opt);
	bsoncxx::builder::basic::array builder;
	for (mongocxx::cursor::iterator it = ret.begin(); it != ret.end(); ++it)
	{
		++m_result.matched_count;
		builder.append(bsoncxx::document::value(*it));
	}
	m_result.val = new bsoncxx::document::value(builder.view());
}

void MongoTask::DoTask_InsertOne(mongocxx::client & client)
{
	mongocxx::collection coll = this->GetColl(client);
	mongocxx::options::insert opt = GenInsertOpt(m_opt->view());
	auto ret = coll.insert_one(m_content->view(), opt);
	if (ret)
	{
		m_result.inserted_ids.push_back(ret->inserted_id().get_oid().value);
	}
}

void MongoTask::DoTask_DeleteOne(mongocxx::client & client)
{
	mongocxx::collection coll = this->GetColl(client);
	mongocxx::options::delete_options opt = GenDeleteOpt(m_opt->view());
	boost::optional<mongocxx::result::delete_result> ret = coll.delete_one(m_filter->view(), opt);
	if (ret)
	{
		m_result.deleted_count = ret->deleted_count();
	}
}

void MongoTask::DoTask_UpdateOne(mongocxx::client & client)
{
	mongocxx::collection coll = this->GetColl(client);
	mongocxx::options::update opt = GenUpdateOpt(m_opt->view());
	boost::optional<mongocxx::result::update> ret = coll.update_one(m_filter->view(), m_content->view(), opt);
	if (ret)
	{
		m_result.matched_count = ret->matched_count();
		m_result.modified_count = ret->modified_count();
		boost::optional<bsoncxx::document::element> upserted_ids = ret->upserted_id();
		if (upserted_ids)
		{
			m_result.upserted_ids.push_back(upserted_ids->get_oid().value);
		}
	}
}

void MongoTask::DoTask_ReplaceOne(mongocxx::client & client)
{
	mongocxx::collection coll = this->GetColl(client);
	mongocxx::options::update opt = GenUpdateOpt(m_opt->view());
	boost::optional<mongocxx::result::replace_one> ret = coll.replace_one(m_filter->view(), m_content->view(), opt);
	if (ret)
	{
		m_result.matched_count = ret->matched_count();
		m_result.modified_count = ret->modified_count();
		boost::optional<bsoncxx::document::element> upserted_ids = ret->upserted_id();
		if (upserted_ids)
		{
			m_result.upserted_ids.push_back(upserted_ids->get_oid().value);
		}
	}
}