
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not CommonClientServer.IsWindowsClient() Then
		
		Raise NStr("ru ='Создание резервной копии поддерживается только в операционной системе Windows.
									|В текущей операционной системе резервная копия делается самостоятельно.'; 
									|en = 'Backup creation is only supported on Windows.
									|Your operating system creates backups automatically.'; 
									|pl = 'Utworzenie kopii zapasowej jest obsługiwane tylko w systemie operacyjnym Windows.
									|W bieżącym systemie operacyjnym kopie zapasową należy robić samodzielnie.';
									|es_ES = 'La creación de la copia de respaldo se admite solo en el sistema operativo Windows.
									|En el sistema operativo actual la copia de respaldo se hace por su cuenta.';
									|es_CO = 'La creación de la copia de respaldo se admite solo en el sistema operativo Windows.
									|En el sistema operativo actual la copia de respaldo se hace por su cuenta.';
									|tr = 'Yedekleme yalnızca Windows işletim sisteminde desteklenir. 
									|Geçerli işletim sisteminde, yedekleme tek başına yapılır.';
									|it = 'La creazione di backup è supportata solo su Windows.
									|Il tuo sistema operativo crea backup automaticamente.';
									|de = 'Backups werden nur auf Windows-Betriebssystemen unterstützt.
									|Im aktuellen Betriebssystem wird die Sicherung selbst durchgeführt.'");
		
	EndIf;
	
	FillPropertyValues(Object, Parameters);
	UpdateControlsStates(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BackupDirectoryFieldStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	Dialog.Directory = Object.IBBackupDirectoryName;
	Dialog.CheckFileExist = True;
	Dialog.Title = NStr("ru = 'Выбор каталога резервной копии ИБ'; en = 'Select infobase backup directory'; pl = 'Wybór katalogu kopii zapasowych bazy informacyjnej';es_ES = 'Seleccionar un directorio de la creación de la copia de respaldo de la infobase';es_CO = 'Seleccionar un directorio de la creación de la copia de respaldo de la infobase';tr = 'Infobase yedekleme dizini seç';it = 'Selezione della directory della copia di backup del database informatico';de = 'Wählen Sie ein Infobasensicherungsverzeichnis'");
	If Dialog.Choose() Then
		Object.IBBackupDirectoryName = Dialog.Directory;
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateBackupOnChange(Item)
	UpdateControlsStates(ThisObject);
EndProcedure

&AtClient
Procedure RestoreInfobaseOnChange(Item)
	UpdateManualRollbackLabel(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OkCommand(Command)
	Cancel = False;
	If Object.CreateBackup = 2 Then
		File = New File(Object.IBBackupDirectoryName);
		Cancel = Not File.Exist() Or Not File.IsDirectory();
		If Cancel Then
			ShowMessageBox(, NStr("ru = 'Укажите существующий каталог для сохранения резервной копии ИБ.'; en = 'Please specify an existing directory for storing the infobase backup.'; pl = 'Wskaż istniejący katalog dla zachowania kopii zapasowej BI.';es_ES = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';es_CO = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';tr = 'IB yedeğini kaydetmek için varolan bir dizini belirtin.';it = 'Si prega di indicare una directory esistente per salvare il backup dell''infobase.';de = 'Geben Sie ein vorhandenes Verzeichnis an, um die IB-Sicherung zu speichern.'"));
			CurrentItem = Items.BackupDirectoryField;
		EndIf;
	EndIf;
	If Not Cancel Then
		SelectionResult = New Structure;
		SelectionResult.Insert("CreateBackup",           Object.CreateBackup);
		SelectionResult.Insert("IBBackupDirectoryName",       Object.IBBackupDirectoryName);
		SelectionResult.Insert("RestoreInfobase", Object.RestoreInfobase);
		Close(SelectionResult);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure UpdateControlsStates(Form)
	
	Form.Items.BackupDirectoryField.AutoMarkIncomplete = (Form.Object.CreateBackup = 2);
	Form.Items.BackupDirectoryField.Enabled = (Form.Object.CreateBackup = 2);
	InfoPages = Form.Items.InformationPanel.ChildItems;
	CreateBackup = Form.Object.CreateBackup;
	InformationPanel = Form.Items.InformationPanel;
	If CreateBackup = 0 Then // Do not create a backup.
		Form.Object.RestoreInfobase = False;
		InformationPanel.CurrentPage = InfoPages.NoRollback;
	ElsIf CreateBackup = 1 Then // Create a temporary backup.
		InformationPanel.CurrentPage = InfoPages.ManualRollback;
		UpdateManualRollbackLabel(Form);
	ElsIf CreateBackup = 2 Then // Create a backup in the specified directory.
		Form.Object.RestoreInfobase = True;
		InformationPanel.CurrentPage = InfoPages.AutomaticRollback;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateManualRollbackLabel(Form)
	LabelPages = Form.Items.ManualRollbackLabelsPages.ChildItems;
	Form.Items.ManualRollbackLabelsPages.CurrentPage = ?(Form.Object.RestoreInfobase,
		LabelPages.Restore, LabelPages.DontRestore);
EndProcedure

#EndRegion
