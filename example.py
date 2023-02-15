#
# Copyright 2020 NVIDIA Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
import sys
sys.path.append('/vpf_app/')
import PyNvCodec as nvc
import numpy as np
import cv2
import os
from time import perf_counter
from threading import Thread

class Worker(Thread):
	def __init__(self, video_stream, thread_num):
		Thread.__init__(self)

		self.gpu_id = 0
		self.num_frame = 0
		self.video_stream = video_stream
		self.thread_num = thread_num
		self.pixel_fmt = nvc.PixelFormat.NV12

		# self.PyNvCodec.PixelFormat
		self.cuda_codec = nvc.CudaVideoCodec.H264
		
		self.rtsp_parameters = {'rtsp_transport': 'tcp', 'max_delay': '5000000', 'bufsize': '30000k'}

		self.nvDec = nvc.PyNvDecoder(self.video_stream, self.gpu_id, self.rtsp_parameters)
		
		self.width, self.height = self.nvDec.Width(), self.nvDec.Height()
		# self.hwidth, self.hheight = int(self.width / 2), int(self.height / 2)
		self.hwidth, self.hheight = 416, 416
		self.nvcolorgb_original = nvc.PySurfaceConverter(self.width, self.height, self.nvDec.Format(), nvc.PixelFormat.BGR, self.gpu_id)
		self.nvDwn_original = nvc.PySurfaceDownloader(self.width, self.height, self.nvcolorgb_original.Format(), self.gpu_id)


		self.nvCvt = nvc.PySurfaceConverter(self.width, self.height, self.nvDec.Format(), nvc.PixelFormat.YUV420, self.gpu_id)
		self.nvRes = nvc.PySurfaceResizer(self.hwidth, self.hheight, self.nvCvt.Format(), self.gpu_id)
		self.nvcolor12 = nvc.PySurfaceConverter(self.hwidth, self.hheight, self.nvRes.Format(), nvc.PixelFormat.NV12, self.gpu_id)
		self.nvcolorgb = nvc.PySurfaceConverter(self.hwidth, self.hheight, self.nvcolor12.Format(), nvc.PixelFormat.RGB, self.gpu_id)
		self.nvDwn = nvc.PySurfaceDownloader(self.hwidth, self.hheight, self.nvcolorgb.Format(), self.gpu_id)


	def run(self):
		try:
			while True:
				try:
					start_time = perf_counter()
					rawSurface = self.nvDec.DecodeSingleSurface()
					if not rawSurface.Empty():
						rawFrame_resized = self.resize_frame(rawSurface)
						original_frame = self.original_frame(rawSurface)
						# print('raw', rawFrame.shape)
						try:
							total_fps = 1/(perf_counter() - start_time)
							self.num_frame += 1
							# cv2.imshow('win', original_frame)
							# cv2.waitKey(1)
							if( 0 == self.num_frame % self.nvDec.Framerate() ):
								print(self.thread_num, self.num_frame, original_frame.shape, 'Fps:', total_fps)

						except Exception as e:
							print('Show Error', e)
					else:
						pass

				except nvc.HwResetException:
					print('Continue after HW decoder was reset')
					continue
				
		except Exception as e:
			print(getattr(e, 'message', str(e)))
			# decFile.close()
 
	def resize_frame(self, rawSurface):
		# Converting to YUV420 from NV12 as NV12 doesn't support resizing
		cvtSurface = self.nvCvt.Execute(rawSurface)

		# Converting to required Resolution
		resSurface = self.nvRes.Execute(cvtSurface)

		# Converting to NV12 again for CV2 mat, as NV12 to BGR/RGB is not supported
		nv12Surface = self.nvcolor12.Execute(resSurface)

		# Converting to RGB/BGR from NV12
		rgbSurface = self.nvcolorgb.Execute(nv12Surface)

		# new cpu casted frame of required shape
		rawFrame = np.ndarray(shape=(rgbSurface.HostSize()), dtype=np.uint8)
		success = self.nvDwn.DownloadSingleSurface(rgbSurface, rawFrame)

		if success:
			return rawFrame.reshape(self.hheight, self.hwidth, 3)
		else:
			return None

	def original_frame(self, rawSurface):
		# Converting to RGB/BGR from NV12
		rgbSurface = self.nvcolorgb_original.Execute(rawSurface)

		rawFrame = np.ndarray(shape=(rgbSurface.HostSize()), dtype=np.uint8)
		success = self.nvDwn_original.DownloadSingleSurface(rgbSurface, rawFrame)

		if success:
			return rawFrame.reshape(self.height, self.width, 3)
		else:
			return None

def create_threads(thread_count, source):
	if thread_count == 1:
		th1  = Worker(source, 1)
		th1.start()

	else:
		source_dir = '/videos/'
		video_paths = os.listdir(source_dir)
		for thread_num in range(thread_count):
			video_path = os.path.join(source_dir, video_paths[thread_num])
			th1  = Worker(video_path, thread_num)
			th1.start()

if __name__ == "__main__":
	gpu_1 = 0
	# input_1 = '20201001000012.mp4'
	input_1 = 'rtsp://192.168.5.23:554/user=admin&password=&channel=1&stream=0.sdp?' 
	num_threads = 24
	create_threads(num_threads, input_1)
