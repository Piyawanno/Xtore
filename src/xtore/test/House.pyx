from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer, getBuffer, setBuffer, getString, setString
from xtore.BaseType cimport i16, i32, i64, u64, f128

cdef i32 PET_ENTRY_KEY_SIZE = 8

cdef class House(RecordNode):
	def __repr__(self):
		return f'<House ID={self.IDhouse} Price={self.price} Ownerhouse={self.nameOwner} {self.surnameOwner} Country={self.countryOfhouse} Tel.={self.telephoneHouse}>'

	cdef i64 hash(self):
		return <i64> self.IDhouse

	cdef bint isEqual(self, RecordNode afferHouse):
		cdef House otherHouse = <House> afferHouse
		return self.IDhouse == otherHouse.IDhouse

	cdef readKey(self, i16 version, Buffer *stream):
		self.IDhouse = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, i16 version, Buffer *stream):
		self.price = (<i64 *> getBuffer(stream, 8))[0]
		self.nameOwner = getString(stream)
		self.surnameOwner = getString(stream)
		self.countryOfhouse = getString(stream)
		self.telephoneHouse = getString(stream)

	cdef write(self, Buffer *stream):
		setBuffer(stream, <char *> &self.IDhouse, 8)
		cdef i32 start = stream.position
		stream.position += 4
		setBuffer(stream, <char *> &self.price, 8)
		setString(stream, self.nameOwner)
		setString(stream, self.surnameOwner)
		setString(stream, self.countryOfhouse)
		setString(stream, self.telephoneHouse)
		cdef i32 end = stream.position
		cdef i32 valueSize = end - start
		stream.position = start
		setBuffer(stream, <char *> &valueSize, 4)
		stream.position = end

	cdef i32 compare(self, RecordNode afferHouse):
		cdef House otherHouse = <House> afferHouse
		if self.IDhouse == otherHouse.IDhouse: return 0
		elif self.IDhouse > otherHouse.IDhouse: return 1
		else: return -1

	cdef f128 getRangeValue(self):
		return <f128> self.IDhouse