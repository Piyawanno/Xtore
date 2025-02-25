from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.common.ReplicaIOHandler cimport ReplicaIOHandler
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.BaseType cimport i32
from xtore.test.People cimport People
from xtore.test.PeopleHashStorage cimport PeopleHashStorage

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
	cdef Buffer stream

	def __init__(self):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	cdef run(self, list argv) :
		self.getParser(argv)
		self.getConfig()
		cdef str resourcePath = self.getResourcePath()
		cdef str fileName = "People.Hash.bin"
		cdef str path = os.path.join(resourcePath, fileName)
		cdef dict replica = self.config["primeRing"][0]["childStorageUnit"][0]["storageUnit"]["replica"][0]
		cdef ReplicaIOHandler io = ReplicaIOHandler(fileName, path, [replica])
		cdef PeopleHashStorage storage = PeopleHashStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			storage.enableIterable()
			if isNew: storage.create()
			else: storage.readHeader(0)
			self.writePeople(storage)
		except:
			print(traceback.format_exc())
		io.close()
	
	cdef writePeople(self, BasicStorage storage) :
		cdef People people
		cdef int n = self.option.count
		cdef object fake = Faker()
		for _ in range(n) :
			people = People()
			people.position = -1
			people.ID = random.randint(1_000_000_000_000, 9_999_999_999_999)
			people.income = random.randint(20_000, 100_000)
			people.name = fake.first_name()
			people.surname = fake.last_name()
			storage.set(people)
			# print(f">>> {people}")

	cdef getParser(self, list argv) :
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-n", "--count", help="Number of record to test.", default=1, type=int)
		self.option = self.parser.parse_args(argv)

	cdef getConfig(self) :
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			fd.close()

	cdef str getResourcePath(self) :
		cdef str resourcePath
		if IS_VENV: resourcePath = os.path.join(sys.prefix, "var", "xtore")
		else: resourcePath = os.path.join('/', "var", "xtore")
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)
		return resourcePath