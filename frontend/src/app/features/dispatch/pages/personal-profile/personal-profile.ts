import {Component, inject, signal} from '@angular/core';
import {NonNullableFormBuilder, ReactiveFormsModule, Validators} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatIconModule} from '@angular/material/icon';
import {MatInputModule} from '@angular/material/input';
import {AuthService} from '../../../../core/auth/auth.service';

@Component({
  selector: 'app-personal-profile',
  imports: [
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    ReactiveFormsModule,
  ],
  templateUrl: './personal-profile.html',
  styleUrl: './personal-profile.scss',
})
export class PersonalProfile {
  private readonly auth = inject(AuthService);
  private readonly formBuilder = inject(NonNullableFormBuilder);

  protected readonly profileFeedback = signal('');
  protected readonly profileForm = this.formBuilder.group({
    account: this.formBuilder.control({value: '', disabled: true}, [Validators.required]),
    name: this.formBuilder.control('', [Validators.required, Validators.maxLength(50)]),
    phone: this.formBuilder.control('', [Validators.maxLength(20), Validators.pattern(/^[0-9+()\-\s]*$/)]),
  });
  constructor() {
    const user = this.auth.user();
    this.profileForm.patchValue({
      account: user?.account ?? '',
      name: user?.displayName ?? '',
    });
  }

  protected saveProfile(): void {
    if (this.profileForm.invalid) {
      this.profileForm.markAllAsTouched();
      return;
    }

    // The backend currently has no personal-profile update endpoint. Do not
    // present a successful save for data that has not been persisted.
    this.profileFeedback.set('個人資料目前無法更新，請稍後再試。');
  }

}
