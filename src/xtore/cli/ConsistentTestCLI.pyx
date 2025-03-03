from xtore.algorithm.ConsistentHashing cimport ConsistentHashing
from xtore.algorithm.ConsistentNode cimport ConsistentNode
from xtore.instance.RecordNode cimport hashDJB
from argparse import RawTextHelpFormatter
from xtore.BaseType cimport i64, i32, u32

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
		self.getParser(argv)
		self.ringTest = ConsistentHashing()
		self.test_add_node()
		self.test_get_node()
		self.test_remove_node()
		self.test_get_node()

	'''cdef i64 hashingWithConsistent(self, str host):
		cdef bytes keyBytes = host.encode('utf-8')
		cdef u32 keyLen = len(keyBytes)
		cdef i64 hashValue = hashDJB(keyBytes, keyLen) % 1024
		return hashValue'''
	
	cdef i64 hashingWithConsistent(self, object host):  # เปลี่ยนจาก str เป็น object
		cdef bytes keyBytes
		if isinstance(host, str):
			keyBytes = host.encode('utf-8')
		elif isinstance(host, bytes):
			keyBytes = host
		else:
			raise TypeError("Host must be str or bytes")
		
		cdef u32 keyLen = len(keyBytes)
		cdef i64 hashValue = hashDJB(keyBytes, keyLen) % 1024
		return hashValue

	cdef test_add_node(self):
		print("\n[TEST] Adding nodes...")
		nodes = [
			ConsistentNode({"id": 1, "host": "127.0.0.1", "port": 8081}),
			ConsistentNode({"id": 2, "host": "192.168.1.1", "port": 8082}),
			ConsistentNode({"id": 3, "host": "234.54.0.5", "port": 8083}),
			ConsistentNode({"id": 4, "host": "656.125.56.9", "port": 8084}),
			ConsistentNode({"id": 5, "host": "18.6.564.23", "port": 8085}),
			ConsistentNode({"id": 6, "host": "145.56.563.564", "port": 8086}),
		]
		for node in nodes:
			hashValue = self.hashingWithConsistent(node.host)
			self.ringTest.addNodeConsistentHashing(node, hashValue)
			print(f"Added node {node}, Ring: {self.ringTest.ring}")

	cdef test_get_node(self):
		print("\n[TEST] Finding nodes for keys...")
		keys = [b"test_key", b"get85", b"log789289289484"]
		for key in keys:
			hashValue = self.hashingWithConsistent(key)
			assigned_node = self.ringTest.getNodeConsistentHashing(hashValue)
			print(f"Key {key} -> Assigned Node: {assigned_node}")

	cdef test_remove_node(self):
		print("\n[TEST] Removing a node...")
		node_to_remove = ConsistentNode({"id": 2, "host": "192.168.1.1", "port": 8082})
		hashValue = self.hashingWithConsistent(node_to_remove.host)
		self.ringTest.removeNodeConsistentHashing(node_to_remove, hashValue)
		print(f"Removed node {node_to_remove}, Ring: {self.ringTest.sortedKey}")