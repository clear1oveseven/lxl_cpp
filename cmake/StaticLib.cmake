IF (WIN32)
	# ���ɾ�̬��
	SET(static_lib_subfix "static")
	SET(static_lib_name ${lib_name}${static_lib_subfix})
	ADD_LIBRARY(${static_lib_name} STATIC ${all_files})
	# ָ����̬����������
	SET_TARGET_PROPERTIES (${static_lib_name} PROPERTIES OUTPUT_NAME "${lib_name}")
	# ʹ��̬��;�̬��ͬʱ����
	SET_TARGET_PROPERTIES (${lib_name} PROPERTIES CLEAN_DIRECT_OUTPUT 1)
	SET_TARGET_PROPERTIES (${static_lib_name} PROPERTIES CLEAN_DIRECT_OUTPUT 1)
ENDIF()