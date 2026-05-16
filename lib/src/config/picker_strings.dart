/// Every user-facing string the picker renders. Subclass and pass
/// into `HaptPhotoPicker.pick(strings: ...)` to override any line.
///
/// ```dart
/// class MyStrings extends HaptPickerStringsEn {
///   const MyStrings();
///   @override
///   String get pickerTitle => 'Pick a moment';
///   @override
///   String selectedCount(int n) => '$n locked in';
/// }
/// ```
///
/// Nine built-in locales ship out-of-the-box (en, vi, es, fr, de,
/// pt, ja, ko, ar). For everything else, subclass `HaptPickerStrings`
/// directly — the abstract class has no defaults so missed strings
/// fail at compile time, not at runtime.
abstract class HaptPickerStrings {
  const HaptPickerStrings();

  /// Sheet title (also the app-bar text).
  String get pickerTitle;

  /// "Done" button label when nothing is selected (some brands
  /// want this disabled-but-readable, others want "Cancel"-like).
  String get doneLabelEmpty;

  /// "Done (N)" — fed the live count.
  String doneLabelWithCount(int count);

  /// Cancel / dismiss link in the top-left.
  String get cancelLabel;

  /// Album-switcher placeholder when no album is loaded yet.
  String get albumLoadingLabel;

  /// Default "All photos" album label — most apps want this
  /// localized to match the device OS.
  String get allPhotosLabel;

  /// Album-switcher button accessibility label.
  String get albumSwitcherA11yLabel;

  /// Toast shown when the user tries to select beyond [maxSelection].
  String maxSelectionReached(int max);

  /// Body of the empty-state when the album has no media.
  String get emptyAlbumBody;

  /// Title of the system permission-denied state.
  String get permissionDeniedTitle;

  /// Body of the system permission-denied state.
  String get permissionDeniedBody;

  /// CTA on the permission-denied state — opens system Settings.
  String get permissionDeniedSettings;

  /// Aspect-ratio chip labels. Apps that ship custom ratios should
  /// override these by name when constructing
  /// `HaptAspectRatio(label: ...)`.
  String get aspectRatioOriginal;
  String get aspectRatioSquare;
  String get aspectRatioPortrait;
  String get aspectRatioLandscape;

  /// Filter-chip label resolver. Receives the filter's `id`
  /// (e.g. 'mono', 'vivid'); subclasses return the localized label.
  /// Unknown ids should return the id itself so custom filters
  /// without overrides still render readable strings.
  String filterLabel(String id);

  /// "Selected N of M" — read out by screen readers when the user
  /// taps a thumbnail.
  String selectionAnnouncement(int n, int max);
}

// ─── Built-in locales ────────────────────────────────────────────────
//
// Each locale subclasses the abstract base. Apps wanting to ship a
// 10th language just write their own subclass — there's no
// "supported locales" enum that gates them.

class HaptPickerStringsEn extends HaptPickerStrings {
  const HaptPickerStringsEn();
  @override
  String get pickerTitle => 'Select photo';
  @override
  String get doneLabelEmpty => 'Done';
  @override
  String doneLabelWithCount(int count) => 'Done ($count)';
  @override
  String get cancelLabel => 'Cancel';
  @override
  String get albumLoadingLabel => 'Loading…';
  @override
  String get allPhotosLabel => 'All photos';
  @override
  String get albumSwitcherA11yLabel => 'Switch album';
  @override
  String maxSelectionReached(int max) => "You've reached $max items.";
  @override
  String get emptyAlbumBody => 'No photos in this album yet.';
  @override
  String get permissionDeniedTitle => 'Photo access is off';
  @override
  String get permissionDeniedBody =>
      'Allow photo access in Settings to pick photos.';
  @override
  String get permissionDeniedSettings => 'Open Settings';
  @override
  String get aspectRatioOriginal => 'Original';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'Original',
        'mono' => 'Mono',
        'vivid' => 'Vivid',
        'warm' => 'Warm',
        'cool' => 'Cool',
        'bright' => 'Bright',
        'vintage' => 'Vintage',
        'noir' => 'Noir',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) =>
      'Selected $n of $max';
}

class HaptPickerStringsVi extends HaptPickerStrings {
  const HaptPickerStringsVi();
  @override
  String get pickerTitle => 'Chọn ảnh';
  @override
  String get doneLabelEmpty => 'Xong';
  @override
  String doneLabelWithCount(int count) => 'Xong ($count)';
  @override
  String get cancelLabel => 'Huỷ';
  @override
  String get albumLoadingLabel => 'Đang tải…';
  @override
  String get allPhotosLabel => 'Tất cả ảnh';
  @override
  String get albumSwitcherA11yLabel => 'Chuyển album';
  @override
  String maxSelectionReached(int max) => 'Bạn đã chọn đủ $max ảnh.';
  @override
  String get emptyAlbumBody => 'Album này chưa có ảnh nào.';
  @override
  String get permissionDeniedTitle => 'Chưa cấp quyền truy cập ảnh';
  @override
  String get permissionDeniedBody =>
      'Vào Cài đặt và bật quyền truy cập ảnh để tiếp tục.';
  @override
  String get permissionDeniedSettings => 'Mở Cài đặt';
  @override
  String get aspectRatioOriginal => 'Gốc';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'Gốc',
        'mono' => 'Trắng đen',
        'vivid' => 'Rực rỡ',
        'warm' => 'Ấm',
        'cool' => 'Lạnh',
        'bright' => 'Sáng',
        'vintage' => 'Cổ điển',
        'noir' => 'Đen tối',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) => 'Đã chọn $n / $max';
}

class HaptPickerStringsEs extends HaptPickerStrings {
  const HaptPickerStringsEs();
  @override
  String get pickerTitle => 'Seleccionar foto';
  @override
  String get doneLabelEmpty => 'Listo';
  @override
  String doneLabelWithCount(int count) => 'Listo ($count)';
  @override
  String get cancelLabel => 'Cancelar';
  @override
  String get albumLoadingLabel => 'Cargando…';
  @override
  String get allPhotosLabel => 'Todas las fotos';
  @override
  String get albumSwitcherA11yLabel => 'Cambiar álbum';
  @override
  String maxSelectionReached(int max) => 'Has alcanzado las $max fotos.';
  @override
  String get emptyAlbumBody => 'Este álbum aún no tiene fotos.';
  @override
  String get permissionDeniedTitle => 'Acceso a fotos desactivado';
  @override
  String get permissionDeniedBody =>
      'Permite el acceso a las fotos en Ajustes para continuar.';
  @override
  String get permissionDeniedSettings => 'Abrir Ajustes';
  @override
  String get aspectRatioOriginal => 'Original';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'Original',
        'mono' => 'Mono',
        'vivid' => 'Vívido',
        'warm' => 'Cálido',
        'cool' => 'Frío',
        'bright' => 'Brillante',
        'vintage' => 'Vintage',
        'noir' => 'Negro',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) =>
      'Seleccionadas $n de $max';
}

class HaptPickerStringsFr extends HaptPickerStrings {
  const HaptPickerStringsFr();
  @override
  String get pickerTitle => 'Choisir une photo';
  @override
  String get doneLabelEmpty => 'OK';
  @override
  String doneLabelWithCount(int count) => 'OK ($count)';
  @override
  String get cancelLabel => 'Annuler';
  @override
  String get albumLoadingLabel => 'Chargement…';
  @override
  String get allPhotosLabel => 'Toutes les photos';
  @override
  String get albumSwitcherA11yLabel => 'Changer d\'album';
  @override
  String maxSelectionReached(int max) =>
      'Tu as atteint la limite de $max.';
  @override
  String get emptyAlbumBody => 'Cet album est vide pour l\'instant.';
  @override
  String get permissionDeniedTitle => 'Accès aux photos désactivé';
  @override
  String get permissionDeniedBody =>
      'Autorise l\'accès aux photos dans les Réglages pour continuer.';
  @override
  String get permissionDeniedSettings => 'Ouvrir les Réglages';
  @override
  String get aspectRatioOriginal => 'Original';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'Original',
        'mono' => 'Mono',
        'vivid' => 'Vif',
        'warm' => 'Chaud',
        'cool' => 'Froid',
        'bright' => 'Lumineux',
        'vintage' => 'Vintage',
        'noir' => 'Noir',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) =>
      'Sélectionnées $n sur $max';
}

class HaptPickerStringsDe extends HaptPickerStrings {
  const HaptPickerStringsDe();
  @override
  String get pickerTitle => 'Foto auswählen';
  @override
  String get doneLabelEmpty => 'Fertig';
  @override
  String doneLabelWithCount(int count) => 'Fertig ($count)';
  @override
  String get cancelLabel => 'Abbrechen';
  @override
  String get albumLoadingLabel => 'Lädt…';
  @override
  String get allPhotosLabel => 'Alle Fotos';
  @override
  String get albumSwitcherA11yLabel => 'Album wechseln';
  @override
  String maxSelectionReached(int max) =>
      'Du hast die $max-Grenze erreicht.';
  @override
  String get emptyAlbumBody => 'Dieses Album ist noch leer.';
  @override
  String get permissionDeniedTitle => 'Fotozugriff ist aus';
  @override
  String get permissionDeniedBody =>
      'Erlaube den Zugriff auf Fotos in den Einstellungen, um fortzufahren.';
  @override
  String get permissionDeniedSettings => 'Einstellungen öffnen';
  @override
  String get aspectRatioOriginal => 'Original';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'Original',
        'mono' => 'Mono',
        'vivid' => 'Lebhaft',
        'warm' => 'Warm',
        'cool' => 'Kühl',
        'bright' => 'Hell',
        'vintage' => 'Vintage',
        'noir' => 'Noir',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) =>
      '$n von $max ausgewählt';
}

class HaptPickerStringsPt extends HaptPickerStrings {
  const HaptPickerStringsPt();
  @override
  String get pickerTitle => 'Selecionar foto';
  @override
  String get doneLabelEmpty => 'Pronto';
  @override
  String doneLabelWithCount(int count) => 'Pronto ($count)';
  @override
  String get cancelLabel => 'Cancelar';
  @override
  String get albumLoadingLabel => 'Carregando…';
  @override
  String get allPhotosLabel => 'Todas as fotos';
  @override
  String get albumSwitcherA11yLabel => 'Trocar álbum';
  @override
  String maxSelectionReached(int max) =>
      'Você atingiu o limite de $max.';
  @override
  String get emptyAlbumBody => 'Esse álbum ainda não tem fotos.';
  @override
  String get permissionDeniedTitle => 'Acesso às fotos desativado';
  @override
  String get permissionDeniedBody =>
      'Permita o acesso às fotos nos Ajustes para continuar.';
  @override
  String get permissionDeniedSettings => 'Abrir Ajustes';
  @override
  String get aspectRatioOriginal => 'Original';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'Original',
        'mono' => 'Mono',
        'vivid' => 'Vívido',
        'warm' => 'Quente',
        'cool' => 'Frio',
        'bright' => 'Brilhante',
        'vintage' => 'Vintage',
        'noir' => 'Noir',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) =>
      '$n de $max selecionadas';
}

class HaptPickerStringsJa extends HaptPickerStrings {
  const HaptPickerStringsJa();
  @override
  String get pickerTitle => '写真を選択';
  @override
  String get doneLabelEmpty => '完了';
  @override
  String doneLabelWithCount(int count) => '完了 ($count)';
  @override
  String get cancelLabel => 'キャンセル';
  @override
  String get albumLoadingLabel => '読み込み中…';
  @override
  String get allPhotosLabel => 'すべての写真';
  @override
  String get albumSwitcherA11yLabel => 'アルバムを切り替え';
  @override
  String maxSelectionReached(int max) => '最大 $max 件まで選択できます。';
  @override
  String get emptyAlbumBody => 'このアルバムには写真がありません。';
  @override
  String get permissionDeniedTitle => '写真へのアクセスがオフです';
  @override
  String get permissionDeniedBody =>
      '設定で写真へのアクセスを許可してください。';
  @override
  String get permissionDeniedSettings => '設定を開く';
  @override
  String get aspectRatioOriginal => '元のまま';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'オリジナル',
        'mono' => 'モノ',
        'vivid' => 'ビビッド',
        'warm' => 'ウォーム',
        'cool' => 'クール',
        'bright' => 'ブライト',
        'vintage' => 'ヴィンテージ',
        'noir' => 'ノワール',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) => '$max 件中 $n 件を選択';
}

class HaptPickerStringsKo extends HaptPickerStrings {
  const HaptPickerStringsKo();
  @override
  String get pickerTitle => '사진 선택';
  @override
  String get doneLabelEmpty => '완료';
  @override
  String doneLabelWithCount(int count) => '완료 ($count)';
  @override
  String get cancelLabel => '취소';
  @override
  String get albumLoadingLabel => '불러오는 중…';
  @override
  String get allPhotosLabel => '모든 사진';
  @override
  String get albumSwitcherA11yLabel => '앨범 전환';
  @override
  String maxSelectionReached(int max) => '최대 $max개까지 선택할 수 있어요.';
  @override
  String get emptyAlbumBody => '이 앨범에는 사진이 없어요.';
  @override
  String get permissionDeniedTitle => '사진 접근이 꺼져 있어요';
  @override
  String get permissionDeniedBody =>
      '설정에서 사진 접근을 허용해 주세요.';
  @override
  String get permissionDeniedSettings => '설정 열기';
  @override
  String get aspectRatioOriginal => '원본';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => '원본',
        'mono' => '모노',
        'vivid' => '비비드',
        'warm' => '웜',
        'cool' => '쿨',
        'bright' => '브라이트',
        'vintage' => '빈티지',
        'noir' => '누아르',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) => '$max개 중 $n개 선택';
}

class HaptPickerStringsAr extends HaptPickerStrings {
  const HaptPickerStringsAr();
  @override
  String get pickerTitle => 'اختر صورة';
  @override
  String get doneLabelEmpty => 'تم';
  @override
  String doneLabelWithCount(int count) => 'تم ($count)';
  @override
  String get cancelLabel => 'إلغاء';
  @override
  String get albumLoadingLabel => 'جارٍ التحميل…';
  @override
  String get allPhotosLabel => 'كل الصور';
  @override
  String get albumSwitcherA11yLabel => 'تبديل الألبوم';
  @override
  String maxSelectionReached(int max) => 'وصلت إلى الحد الأقصى $max.';
  @override
  String get emptyAlbumBody => 'لا توجد صور في هذا الألبوم بعد.';
  @override
  String get permissionDeniedTitle => 'الوصول إلى الصور معطل';
  @override
  String get permissionDeniedBody =>
      'اسمح بالوصول إلى الصور من الإعدادات للمتابعة.';
  @override
  String get permissionDeniedSettings => 'فتح الإعدادات';
  @override
  String get aspectRatioOriginal => 'أصلي';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'أصلي',
        'mono' => 'أحادي',
        'vivid' => 'نابض',
        'warm' => 'دافئ',
        'cool' => 'بارد',
        'bright' => 'ساطع',
        'vintage' => 'كلاسيكي',
        'noir' => 'نوار',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) => 'محدد $n من $max';
}
