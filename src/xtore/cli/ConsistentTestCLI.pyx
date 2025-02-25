from xtore.algorithm.ConsistentHashing cimport ConsistentHashing
from xtore.algorithm.ConsistentNode cimport ConsistentNode
from xtore.instance.RecordNode cimport hashDJB
from argparse import RawTextHelpFormatter

import os, sys, argparse, traceback, random, time

cdef str __help__ = "Test Script for Xtore"
cdef bint IS_VENV = sys.prefix != sys.base_prefix


def run():
	cli = ConsistentTestCLI()
	cli.run(sys.argv[1:])

cdef class ConsistentTestCLI:
	cdef object parser
	cdef object option
	cdef ConsistentHashing ringTest


	
	def getParser(self, list argv):
		self.parser = argparse.ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
		self.option = self.parser.parse_args(argv)

	"""cdef run(self, list argv):
		self.getParser(argv)
		self.ringTest = ConsistentHashing()
		print(self.ringTest.ring)"""


	cdef run(self, list argv):
		""" รัน CLI และเริ่มทดสอบ ConsistentHashing """
		self.getParser(argv)
		self.ringTest = ConsistentHashing()
		self.test_add_node()
		self.test_get_node()
		self.test_remove_node()

	cdef test_add_node(self):
		""" ทดสอบการเพิ่มโหนด """
		print("\n[TEST] Adding nodes...")
		nodes = [
			ConsistentNode({"id": 1, "host": "127.0.0.1", "port": 8080}),
			ConsistentNode({"id": 2, "host": "192.168.1.1", "port": 9090}),
			ConsistentNode({"id": 3, "host": "10.0.0.1", "port": 7070}),
		]
		for node in nodes:
			self.ringTest.addNodeConsistentHashing(node)
			print(f"Added node {node}, Ring: {self.ringTest.ring}")

	cdef test_get_node(self):
		""" ทดสอบการหาโหนดที่เก็บคีย์ """
		print("\n[TEST] Finding nodes for keys...")
		keys = [b"user123", b"data456", b"log789"]
		for key in keys:
			assigned_node = self.ringTest.getNodeConsistentHashing(key)
			print(f"Key '{key.decode()}' -> Assigned Node: {assigned_node}")

	cdef test_remove_node(self):
		""" ทดสอบการลบโหนด """
		print("\n[TEST] Removing a node...")
		node_to_remove = ConsistentNode({"id": 2, "host": "192.168.1.1", "port": 9090})
		self.ringTest.removeNodeConsistentHashing(node_to_remove)
		print(f"Removed node {node_to_remove}, Ring: {self.ringTest.ring}")

# ✅ ฟังก์ชัน main() ให้รันทดสอบโดยตรง
def main():
	cli = ConsistentTestCLI()
	cli.run([])

	

		


