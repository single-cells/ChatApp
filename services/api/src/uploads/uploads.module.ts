import { Module } from '@nestjs/common';
import { StorageService } from '../common/storage.service';
import { RoomsModule } from '../rooms/rooms.module';
import { MediaController } from './media.controller';
import { UploadsController } from './uploads.controller';

@Module({
  imports: [RoomsModule],
  controllers: [UploadsController, MediaController],
  providers: [StorageService],
  exports: [StorageService],
})
export class UploadsModule {}
