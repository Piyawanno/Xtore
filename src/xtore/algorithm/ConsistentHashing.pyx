from xtore.algorithm.ConsistentNode cimport ConsistentNode
from xtore.instance.RecordNode cimport hashDJB
from xtore.BaseType cimport i64, i32, u32
import json, random, sys, os


cdef class ConsistentHashing:
	def __init__(self):
		self.ring = {}
		self.consistentConfig = []
		self.consistentNode = []
		self.replicationFactor = 3  # Default replication factor
		self.nodes = []
		self.nodeNumber = 0
		self.maxNode = 1024

	def __str__(self):
		return f"Nodes: {[node.id for node in self.nodes]}"

	cdef loadData(self, dict config):
		self.consistentConfig = config["primeRing"]
		cdef ConsistentNode consistentNode
		for node in self.consistentConfig:
			consistentNode = ConsistentNode(node)
			self.nodes.append(consistentNode)
			self.nodeNumber += 1
		self.createNodeId()
		return {"primeRing": self.consistentConfig}

	cdef createNodeId(self): #เอา nodes ไปเขียนใหม่แทน config เดิม
		cdef set usedIds = set()  #เก็บidที่ใช้แล้ว
		cdef ConsistentNode node
		cdef i32 nodeId
		
		#เก็บ id ที่มีอยู่แล้วจาก config
		for i in range(len(self.consistentConfig)):
			if "id" in self.consistentConfig[i] and self.consistentConfig[i]["id"] is not None:
				usedIds.add(self.consistentConfig[i]["id"])

		#อัปเดต id เฉพาะโหนดที่ยังไม่มี
		for node in self.nodes:
			if not hasattr(node, "id") or node.id is None or node.id < 0: #ยังไม่กำหนดหรือว่าเป็นค่า -1
				while True:
					nodeId = random.randint(0, self.maxNode-1)
					if nodeId not in usedIds:
						usedIds.add(nodeId)
						node.id = nodeId
						break

		#อัปเดตconfig
		cdef i32 j
		for j in range(len(self.nodes)):
			self.consistentConfig[j]["id"] = self.nodes[j].id
			print(f"Updated node {j} with id: {self.nodes[j].id}")

	cdef initConsistent(self):
		self.consistentNode = sorted(self.nodes, key=lambda node: node.id)
		self.nodes = self.consistentNode

		#เรียงลำดับในring
		self.ring.clear()  # ล้าง ring เดิม
		for node in self.consistentNode:
			self.ring[node.id] = node
	

	cdef list[ConsistentNode] getNodeList(self, i64 hashKey):
		cdef i32 hashMod = hashKey % self.maxNode
		print(hashMod)
		cdef list nodes = []  
		cdef ConsistentNode node
		cdef i32 i, nodeIndex = -1
		cdef i32 currentIndex
		cdef i32 length = len(self.consistentNode)

		# หาโหนดแรกที่ id >= hash
		for i in range(length):
			if self.consistentNode[i].id >= hashMod:
				nodeIndex = i
				break
		if nodeIndex == -1:  # ถ้าไม่มี id >= hashMod ให้เลือกโหนดแรก
			nodeIndex = 0

		# เลือกโหนดตาม replication factor
		for i in range(self.replicationFactor):
			currentIndex = (nodeIndex + i) % length
			nodes.append(self.consistentNode[currentIndex])
			print(self.consistentNode[currentIndex])

		return nodes