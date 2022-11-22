/*
 * file       : nfb_driver.h
 * Copyright (C) 2022 CESNET z. s. p. o.
 * description: create interprocess comunication with nfb programs 
 * date       : 2022
 * author     : Radek Iša <isa@cesnet.ch>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

typedef struct {
	unsigned int buff_size;
	void * buff;
	mqd_t req;
	mqd_t res;
} nfb_sv_struct_t;

typedef enum {SEND_NULL, GET_FDT, SEND_DATA, READ_DATA} msg_type_t;
typedef struct {
	msg_type_t   type;
	uint32_t size;
	uint64_t offset;
} msg_t;

void * nfb_sv_create(const char * path, unsigned int msg_size);
void   nfb_sv_close(void * mq_id, const char * path);
int    nfb_sv_cmd_get(void * id, unsigned int* cmd, unsigned int* data_size, svLogicVecVal* offset);
void   nfb_sv_data_get(void * id, const svOpenArrayHandle out);
void   nfb_sv_cmd_send(void * id, unsigned int cmd, const svOpenArrayHandle out);

