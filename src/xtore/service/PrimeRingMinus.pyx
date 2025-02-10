from argparse import ArgumentParser, RawTextHelpFormatter
import sys, random

cdef str __help__ =""

def run():
    cdef TestCLI cli = TestCLI()
    cli.run(sys.argv[1:])

cdef class TestCLI:
    cdef object parser
    cdef object option

    def __init__(self):
        pass

    def getParser(self, list argv):
        self.parser = ArgumentParser(description=__help__, formatter_class=RawTextHelpFormatter)
        self.parser.add_argument("-r", "--range", help="Set the range of the random number (min,max).", default="1,100", type=str)
        self.option = self.parser.parse_args(argv)

    cdef run(self, list argv):
        self.getParser(argv)
        
        cdef list range_values = self.option.range.split(',')
        cdef int min_value = int(range_values[0])
        cdef int max_value = int(range_values[1])

        random_number = random.randint(min_value, max_value)

        print(f"random number between {min_value} and {max_value}:")
        print(random_number)