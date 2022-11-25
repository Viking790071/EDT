
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	HasDataImportSource = ValueIsFilled(Constants.BankClassifierImportProcessor.Get());
	
	CanUpdateClassifier = 
		Not Common.DataSeparationEnabled() // Automatic update in SaaS mode.
		AND Not Common.IsSubordinateDIBNode()   // The distributed infobase node is updated automatically.
		AND AccessRight("Update", Metadata.Catalogs.BankClassifier); //  A user with sufficient rights.
	
	Items.FormImportClassifier.Visible = CanUpdateClassifier AND HasDataImportSource;
	
	If Not Users.IsFullUser() Or Not CanUpdateClassifier Then
		ReadOnly = True;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		For each FormItem In Items.CommandBar.ChildItems Do
			
			Items.Move(FormItem, Items.CommandBarForm);
			
		EndDo;
		
		CommonClientServer.SetFormItemProperty(Items, "FormImportClassifier", "Title", NStr("ru ='Загрузить'; en = 'Import'; pl = 'Moc';es_ES = 'Importar';es_CO = 'Importar';tr = 'İçe aktar';it = 'Importazione';de = 'Import'"));
		CommonClientServer.SetFormItemProperty(Items, "FormImportClassifier", "DefaultButton", True);
		CommonClientServer.SetFormItemProperty(Items, "FormImportClassifier", "DefaultItem", True);
		
		CommonClientServer.SetFormItemProperty(Items, "FormCreate", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "FormCreateMobileClient", "Visible", True);
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportClassifier(Command)
	BankManagerClient.OpenClassifierImportForm(ThisObject, True);
EndProcedure

#EndRegion


#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OutOfBusiness");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion