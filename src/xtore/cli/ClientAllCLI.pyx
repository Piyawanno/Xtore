from xtore.common.ClientHandler cimport ClientHandler
from xtore.test.Package cimport Package
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
	cli = ClientAllCLI()
	cli.run(sys.argv[1:])

cdef class ClientAllCLI:
	cdef object parser
	cdef object option
	cdef ClientHandler handler
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
		self.handler = ClientHandler(self.getConfig())
		self.handler.send(message)

	cdef bytes pack(self) :
		cdef Package package = Package()
		package.position = -1
		package.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
		package.method = self.option.method
		print(package.method)
		package.data = self.genDynamicFields()
		print(package.data)
		print(len(package.data))
		print(package)
		package.write(&self.stream)
		print('write')
		print(package)
		return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)

	cdef str genDynamicFields(self) :
		cdef dict data = {}
		data["table_name"] = "Company"
		data["storage_method"] = "DataHashStorage"
		while True:
			key = input("Enter field name: ").strip()
			if not key:
				break
			value = input(f"Enter value for '{key}': ").strip()
			try:
				data[key] = int(value)
			except ValueError:
				data[key] = value
		return json.dumps(data)

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