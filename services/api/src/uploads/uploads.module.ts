import { Module } from '@nestjs/common';
import { StorageService } from '../common/storage.service';
import { RoomsModule } from '../rooms/rooms.module';
import { UploadsController } from './uploads.controller';

@Module({
  imports: [RoomsModule],
  controllers: [UploadsController],
  providers: [StorageService],
  exports: [StorageService],
})
export class UploadsModule {}
