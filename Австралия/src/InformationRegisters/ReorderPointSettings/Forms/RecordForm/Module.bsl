#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Not ValueIsFilled(Record.SourceRecordKey.Products) Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Record.Company = SettingValue;
		Else
			Record.Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Record.Company = Constants.ParentCompany.Get();
		Items.Company.ReadOnly = True;
	EndIf; 
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Record.InventoryMinimumLevel > Record.InventoryMaximumLevel Then
		DriveServer.ShowMessageAboutError(ThisObject,
			NStr("en = 'Minimum cannot be geater than Maximum.'; ru = 'Минимум не может быть больше Максимума';pl = 'Minimum nie może być większy niż Maksimum.';es_ES = 'El Mínimo no puede ser mayor que el Máximo.';es_CO = 'El Mínimo no puede ser mayor que el Máximo.';tr = 'Minimum değer Maksimum değerden büyük olamaz.';it = 'Il Minimo non può essere maggiore del Massimo.';de = 'Minimum darf Maximum nicht überschreiten.'"),
			,
			,
			"Record.InventoryMaximumLevel",
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion