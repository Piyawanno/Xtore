from xtore.common.ClientHandler cimport ClientHandler
from xtore.test.People cimport People
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer, getBytes
from xtore.BaseType cimport i32

from libc.stdlib cimport malloc
from cpython cimport PyBytes_FromStringAndSize
from faker import Faker
from argparse import RawTextHelpFormatter
import os, sys, argparse, json, traceback, random, time

cdef str __help__ = ''
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cdef MasterStoreCLI service = MasterStoreCLI()
	service.run(sys.argv[1:])

cdef class MasterStoreCLI :
	cdef dict config
	cdef object parser
	cdef object option
	cdef ClientHandler handler
	cdef Buffer stream

	def __init__(self):
		pass

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	cdef run(self, list argv) :
		self.getParser(argv)
		self.getConfig()
		self.checkPath()
		cdef bytes message = self.getStoreMessage()
		self.handler = ClientHandler(self.config["node"][0])
		self.handler.send(message)
	
	cdef bytes getStoreMessage(self) :
		cdef object fake = Faker()
		cdef People people = People()
		people.position = -1
		people.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
		people.name = fake.first_name()
		people.surname = fake.last_name()
		print(people)
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		people.write(&self.stream)
		return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		# self.parser.add_argument("-n", "--count", help="Number of record to test.", required=True, type=int)
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()

	cdef checkPath(self) :
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self) :
		if IS_VENV: return os.path.join(sys.prefix, "var", "xtore")
		else: return os.path.join('/', "var", "xtore")