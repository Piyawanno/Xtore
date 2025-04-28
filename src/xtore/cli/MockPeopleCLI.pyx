from xtore.BaseType cimport i32

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from cpython cimport PyBytes_FromStringAndSize

from faker import Faker
from argparse import ArgumentParser, RawTextHelpFormatter

import os, sys, json, random

cdef str __help__ = ""
cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

def run():
	cli = MockPeopleCLI()
	cli.run(sys.argv[1:])

cdef class MockPeopleCLI:
	cdef object parser
	cdef object option
	cdef dict config

	def getParser(self, list argv):
		self.parser = ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.parser.add_argument("-n", "--number", help="Amount number of record", default=100, type=int)
		self.parser.add_argument("-f", "--file", help="File name", default="people", type=str)
		self.option = self.parser.parse_args(argv)

	cdef run(self, list argv):
		self.getParser(argv)
		self.generatedPeopleToTSV()

	cdef generatedPeopleToTSV(self):
		cdef int n = self.option.number
		faker = Faker()
		cdef list rows = ["ID\tincome\tname\tsurname"]
		cdef str configPath = os.path.join(sys.prefix, "etc", "testcase", f"{self.option.file}.tsv")
		for _ in range(n):
			_id = random.getrandbits(16)
			_income = random.randint(20_000, 100_000)
			_name = faker.first_name()
			_surname = faker.last_name()
			rows.append(f"{_id}\t{_income}\t{_name}\t{_surname}")

		# Write to file
		if not os.path.exists(os.path.dirname(configPath)):
			os.makedirs(os.path.dirname(configPath))
		with open(configPath, "w", encoding="utf-8") as f:
			f.write("\n".join(rows))

		print(f"Generated {n} records to {self.option.file}.tsv")
