import {HttpErrorResponse} from '@angular/common/http';
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
  protected readonly profileError = signal('');
  protected readonly isLoading = signal(true);
  protected readonly hasLoadedProfile = signal(false);
  protected readonly isSaving = signal(false);
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
    this.auth.loadProfile().subscribe({
      next: (profile) => {
        this.profileForm.patchValue({account: profile.account, name: profile.name, phone: profile.phone ?? ''});
        this.hasLoadedProfile.set(true);
        this.isLoading.set(false);
      },
      error: () => {
        this.profileError.set('無法載入個人資料，請重新整理頁面再試。');
        this.isLoading.set(false);
      },
    });
  }

  protected saveProfile(): void {
    if (this.profileForm.invalid || !this.hasLoadedProfile() || this.isSaving()) {
      this.profileForm.markAllAsTouched();
      return;
    }
    this.profileError.set('');
    this.profileFeedback.set('');
    this.isSaving.set(true);
    this.auth.updateProfile({
      name: this.profileForm.controls.name.value.trim(),
      phone: this.profileForm.controls.phone.value.trim() || null,
    }).subscribe({
      next: (profile) => {
        this.profileForm.patchValue({name: profile.name, phone: profile.phone ?? ''});
        this.profileFeedback.set('個人資料已儲存。');
        this.isSaving.set(false);
      },
      error: (error: HttpErrorResponse) => {
        this.profileError.set(error.error?.message ?? '無法儲存個人資料，請稍後再試。');
        this.isSaving.set(false);
      },
    });
  }

}
