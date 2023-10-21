import sys
from PyQt5.QtWidgets import QApplication, QMainWindow, QPushButton,  QPlainTextEdit
from Ui_simple import *
from PyQt5.QtCore import QThread, pyqtSignal, QTimer
import time



class DelayThread(QThread):
    signal_subthread = pyqtSignal(object)

    def __init__(self,delay_valuie, parent=None):
        super(DelayThread, self).__init__(parent)
        # QThread.__init__(self)
        self.delay_valuie = delay_valuie
    
    def run(self):
        while True:
            if self.delay_valuie !=0 :
                time.sleep(self.delay_valuie)
                self.signal_subthread.emit(int(1))
            else:
                pass

class MyMainWindow(QMainWindow, Ui_MainWindow):
    def __init__(self, parent=None):
        super(MyMainWindow, self).__init__(parent)
        self.setupUi(self)

        # bonding signal and slot
        
        self.delay_thread = DelayThread(0)

        timer = QTimer(self)
        timer.timeout.connect(self.display_info)
        timer.start(1000)

        self.pushButton.clicked.connect(self.update_delay)
        self.delay_thread.signal_subthread.connect(self.delay_finished)

        self.delay_thread.start()


    # display the user name and password into the editbox
    def display_info(self):
        current_time = time.ctime()
        self.plainTextEdit.appendPlainText(current_time)

    def update_delay(self):
        self.delay_thread.delay_valuie = 5

    def delay_finished(self):
        self.delay_thread.delay_valuie =0
        self.plainTextEdit.appendPlainText(str("delay tread finished"))
        


if __name__ == "__main__":
    # create an application
    app = QApplication(sys.argv)
    # initialize the window
    myWin = MyMainWindow()
    # display the window
    myWin.show()
    # exit the program
    sys.exit(app.exec_())