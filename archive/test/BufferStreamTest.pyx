#cython: language_level=3

from xtore.common.BufferStream cimport BufferStream

def testBufferStream():
	stream = BufferStream(1024)
	stream.setBool(True)

	stream.reset()
	cdef bint data = stream.getBool()
	print(f'>>> bool : {data}')