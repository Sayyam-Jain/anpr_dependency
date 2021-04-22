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
		self.hwidth, self.hheight = int(self.width / 2), int(self.height / 2)
		print(self.hwidth, self.hheight)

		self.nvCvt = nvc.PySurfaceConverter(self.width, self.height, self.nvDec.Format(), nvc.PixelFormat.YUV420, self.gpu_id)
		# print('self.nvCvt.Format()', self.nvCvt.Format())
		self.nvRes = nvc.PySurfaceResizer(self.hwidth, self.hheight, self.nvCvt.Format(), self.gpu_id)
		self.nvcolor12 = nvc.PySurfaceConverter(self.hwidth, self.hheight, self.nvRes.Format(), nvc.PixelFormat.NV12, self.gpu_id)
		self.nvcolorgb = nvc.PySurfaceConverter(self.hwidth, self.hheight, self.nvcolor12.Format(), nvc.PixelFormat.BGR, self.gpu_id)
		self.nvDwn = nvc.PySurfaceDownloader(self.hwidth, self.hheight, self.nvcolorgb.Format(), self.gpu_id)
		print('self.nvcolorgb.Format()', self.nvcolorgb.Format())

	def run(self):
		try:
			while True:
				try:
					start_time = perf_counter()
					rawSurface = self.nvDec.DecodeSingleSurface()
					if (rawSurface.Empty()):
						print('No more video frames')
						break
				except nvc.HwResetException:
					print('Continue after HW decoder was reset')
					continue
 
				cvtSurface = self.nvCvt.Execute(rawSurface)
				if (cvtSurface.Empty()):
					print('Failed to do color conversion')
					break

				resSurface = self.nvRes.Execute(cvtSurface)
				if (resSurface.Empty()):
					print('Failed to resize surface')
					break
 				##########################

				nv12Surface = self.nvcolor12.Execute(resSurface)
				if (nv12Surface.Empty()):
					print('Failed to do color conversion NV12')
					break

				rgbSurface = self.nvcolorgb.Execute(nv12Surface)
				if (rgbSurface.Empty()):
					print('Failed to do color conversion RGB')
					break


				##########################

				rawFrame = np.ndarray(shape=(rgbSurface.HostSize()), dtype=np.uint8)
				# success = self.nvcolorgb.DecodeSingleFrame(rgbSurface)
				success = self.nvDwn.DownloadSingleSurface(rgbSurface, rawFrame)
				# print('raw', rawFrame.shape)
				try:
					new_frame = rawFrame.reshape(self.hheight, self.hwidth, 3)
					total_fps = 1/(perf_counter() - start_time)
					# print(new_frame.shape)
					# cv2.imshow('win', new_frame)
					# cv2.waitKey(1)
				except Exception as e:
					print('Show Error', e)
				# success = self.nvDec.DecodeSingleFrame(rawFrame)
				if not (success):
					print('Failed to download surface')
					break
 
				self.num_frame += 1
				if( 0 == self.num_frame % self.nvDec.Framerate() ):
					print(self.thread_num, self.num_frame, rawFrame.shape, 'Fps:', total_fps)

					# rawFrame.reshape(self.hwidth, self.hheight, 3)
					# self.garbage_frame = rawFrame.copy()
					# print(self.garbage_frame.shape)
					# self.garbage_frame.reshape(self.hwidth, self.hheight, 3)
					# print(rawFrame.shape)
					# try:
					# 	cv2.imshow('win', rawFrame)
					# 	cv2.waitKey(1)
					# except Exception as e:
					# 	print('Show Error', e)
 
		except Exception as e:
			print(getattr(e, 'message', str(e)))
			# decFile.close()
 
def create_threads(thread_count):
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
	create_threads(num_threads)
