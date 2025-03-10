from xtore.service.Client cimport Client
from xtore.common.Packet cimport Packet
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.BaseType cimport i32, u64

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize
import os, sys, argparse, json, traceback, random, time

from faker import Faker
from argparse import RawTextHelpFormatter

import os, sys, argparse, traceback, random, time

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cli = DBClientCLI()
	cli.run(sys.argv[1:])

cdef class DBClientCLI:
	cdef object parser
	cdef object option
	cdef Client service
	cdef Buffer stream

	def __init__(self):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self):
		releaseBuffer(&self.stream)
	
	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-u", "--host", help="Target Server host.", required=False, type=str, default='127.0.0.1')
		self.parser.add_argument("-p", "--port", help="Target Server port.", required=True, type=int)
		self.parser.add_argument("-m", "--message", help="Sending Message.", required=False, type=str)
		self.parser.add_argument("-s", "--method", help="Select Method", required=True, choices=['Get', 'Set'])
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.checkPath()
		cdef bytes message = self.pack()
		self.service = Client(self.getConfig())
		self.service.send(message)

	cdef bytes pack(self) :
		cdef object fake = Faker()
		cdef Packet packet = Packet()
		packet.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
		packet.header = json.dumps({
			"method": self.option.method,
			"mode" : "hash"
		})
		packet.data = self.option.message or json.dumps({
			"table_name" : "People",
			"storage_method" : "PeopleHashStorage",
			"name" : fake.first_name(),
			"surname" : fake.last_name()
		})
		print(packet)
		packet.write(&self.stream)
		return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)

	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return (f'{sys.prefix}/var/xtore').encode('utf-8').decode('utf-8')
		else: return '/var/xtore'

	cdef getConfig(self):
		return {
			"host" : self.option.host,
			"port" : self.option.port
		}