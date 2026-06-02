import { Body, Controller, Patch, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UpdateUserDto } from './dto/update-user.dto';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(AuthGuard('jwt'))
export class UsersController {
  constructor(private users: UsersService) {}

  @Patch('me')
  updateMe(
    @Req() req: { user: { userId: string } },
    @Body() dto: UpdateUserDto,
  ) {
    return this.users.updateMe(req.user.userId, dto);
  }
}
