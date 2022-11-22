/* SPDX-License-Identifier: BSD-3-Clause */
/*
 * libnfb extension for SystemVerilog communication
 *
 * Copyright (C) 2022 CESNET
 * Author(s):
 *  Radek Iša <isa@cesnet.cz>
 */

#include <stdio.h>

#include <libfdt.h>
#include <nfb/nfb.h>
#include <mqueue.h>
#include <errno.h>

#include <libfdt.h>
#include <nfb/nfb.h>
#include <nfb/ext.h>

typedef enum {SEND_NULL, GET_FDT, SEND_DATA, READ_DATA} msg_type_t;

typedef struct {
	msg_type_t type;
	uint32_t size;
	uint64_t offset;
} msg_t;

typedef struct {
	mqd_t req;
	mqd_t res;
	char  buffer[8192];
} private_t;

static const char *nfb_inf_prefix = "sv:";

static int nfb_inf_open(const char *devname, int oflag, void **priv_out, void **fdt)
{
	private_t *priv;
	struct mq_attr attr;
	int unsigned name_size;
	const char  *name;
	msg_t * msg;

	priv = malloc(sizeof (private_t));
	if (priv == NULL) {
		return -ENODEV;
	}
	msg = (void *) priv->buffer;
	*priv_out = priv;

	name      = devname + strlen(nfb_inf_prefix);
	name_size = strlen(name);
	memcpy(priv->buffer, name, name_size);

	memcpy(priv->buffer + name_size, "_req", 5);
	priv->req = mq_open(priv->buffer, O_WRONLY);
	if (priv->req == -1) {
		fprintf(stderr, "Cannot create %s : %s\n", devname + strlen(nfb_inf_prefix), strerror(errno));
		free(priv);
		return -ENODEV;
	}

	memcpy(priv->buffer + name_size, "_res", 5);
	priv->res = mq_open(priv->buffer, O_RDONLY);
	if (priv->res == -1) {
		fprintf(stderr, "Cannot create %s : %s\n", devname + strlen(nfb_inf_prefix), strerror(errno));
		mq_close(priv->req);
		free(priv);
		return -ENODEV;
	}

	// ask for FDT
	msg->type   = GET_FDT;
	msg->size   = 0;
	msg->offset = 0;
	mq_send(priv->req, priv->buffer, sizeof(msg_t), 0);

	// receive FDT
	mq_receive(priv->res, priv->buffer, 8192, NULL);
	*fdt = malloc(msg->size);
	if (*fdt == NULL) {
		fprintf(stderr, "Cannot allocate enought space for fdt\n");
		mq_close(priv->req);
		mq_close(priv->res);
		free(priv);
		return -ENODEV;
	}
	memcpy(*fdt, priv->buffer + sizeof(msg_t), msg->size);
	return 0;
}

static void nfb_inf_close(void *bus_priv)
{
	private_t *priv = bus_priv;
	mq_close(priv->req);
	mq_close(priv->res);
	free(priv);
}

static ssize_t nfb_inf_bus_read(void *bus_priv, void *buf, size_t nbyte, off_t offset)
{
	private_t *priv = bus_priv;
	msg_t * msg = (void *)priv->buffer;

	if (nbyte > (8192 - sizeof(msg_t))) {
		return 0;
	}

	msg->type   = READ_DATA;
	msg->size   = nbyte;
	msg->offset = offset;
	mq_send(priv->req, priv->buffer, sizeof(msg_t), 0);

	mq_receive(priv->res, priv->buffer, 8192, NULL);
	memcpy(buf, priv->buffer + sizeof(msg_t), nbyte);

	return nbyte;
}

static ssize_t nfb_inf_bus_write(void *bus_priv, const void *buf, size_t nbyte, off_t offset)
{
	private_t *priv = bus_priv;
	msg_t * msg =  (void *)priv->buffer;

	if (nbyte > (8192 - sizeof(msg_t))) {
		return 0;
	}

	msg->type   = SEND_DATA;
	msg->size   = nbyte;
	msg->offset = offset;
	memcpy(priv->buffer + sizeof(msg_t), buf, nbyte);
	mq_send(priv->req, priv->buffer, sizeof(msg_t) + nbyte, 0);

	return nbyte;
}

static int nfb_inf_bus_open(void *dev_priv, int bus_node, int comp_node, void **bus_priv, struct libnfb_bus_ext_ops* ops)
{
	ops->read  = nfb_inf_bus_read;
	ops->write = nfb_inf_bus_write;
	*bus_priv  = dev_priv;

	return 0;
}

static void nfb_inf_bus_close(void *bus_priv)
{
	msg_t     *msg;
	private_t *priv = bus_priv;

	msg = (void *) priv->buffer;
	msg->type = SEND_NULL;
	msg->size = 0;
	mq_send(priv->req, priv->buffer, sizeof(msg_t), 0);
}

static int nfb_inf_comp_lock(const struct nfb_comp *comp, uint32_t features)
{
	printf("MI BUS LOCK\n");
	fflush(stdout);
	/* TODO */
	return 1;
}

static void nfb_inf_comp_unlock(const struct nfb_comp *comp, uint32_t features)
{
	printf("MI BUS UNLOCK\n");
	fflush(stdout);
	/* TODO */
}

const struct libnfb_ext_abi_version libnfb_ext_abi_version = libnfb_ext_abi_version_current;

int libnfb_ext_get_ops(const char *devname, struct libnfb_ext_ops *ops)
{
	if (strncmp(devname, nfb_inf_prefix, strlen(nfb_inf_prefix)) == 0) {
		ops->open         = nfb_inf_open;
		ops->close        = nfb_inf_close;
		ops->bus_open_mi  = nfb_inf_bus_open;
		ops->bus_close_mi = nfb_inf_bus_close;
		ops->comp_lock    = nfb_inf_comp_lock;
		ops->comp_unlock  = nfb_inf_comp_unlock;
		return 1;
	} else {
		return 0;
	}
}
