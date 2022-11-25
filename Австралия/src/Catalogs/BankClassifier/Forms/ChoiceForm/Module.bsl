
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CloseOnElementChoice = Parameters.CloseOnChoice; // Drive
	
	DataProcessorName = "ImportBankClassifier";
	HasDataImportSource = Metadata.DataProcessors.Find(DataProcessorName) <> Undefined;
	
	CanUpdateClassifier =
		Not Common.DataSeparationEnabled() // Automatic update in SaaS mode.
		AND Not Common.IsSubordinateDIBNode()   // The distributed infobase node is updated automatically.
		AND AccessRight("Update", Metadata.Catalogs.BankClassifier); //  A user with sufficient rights.

	Items.FormImportClassifier.Visible = CanUpdateClassifier AND HasDataImportSource;
	
	If Not Users.IsFullUser() Or Not CanUpdateClassifier Then
		ReadOnly = True;
	EndIf;
	
	SwitchInactiveBanksVisibility(False);
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommonClientServer.SetFormItemProperty(Items, "FormCreate", "OnlyInAllActions", True);
		CommonClientServer.SetFormItemProperty(Items, "FormCreateFolder", "OnlyInAllActions", True);
		CommonClientServer.SetFormItemProperty(Items, "FormImportClassifier", "Title", NStr("ru ='Загрузить'; en = 'Import'; pl = 'Importuj';es_ES = 'Importar';es_CO = 'Importar';tr = 'İçe aktar';it = 'Importazione';de = 'Import'"));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportClassifier(Command)
	BankManagerClient.OpenClassifierImportForm(ThisObject);
EndProcedure

&AtClient
Procedure ShowInactiveBanks(Command)
	SwitchInactiveBanksVisibility(Not Items.FormShowInactiveBanks.Check);
EndProcedure

#EndRegion

#Region Private

 ////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtServer
Procedure BankClassificatorSelection(Refs)
	
	BankOperationsDrive.BankClassificatorSelection(Refs);
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ProcessSelection(SelectedRow, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	ProcessSelection(Value, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ProcessSelection(SelectedRows, StandardProcessing)
	
	If TypeOf(SelectedRows) <> Type("Array") Then
		Return;
	EndIf;
	
	StandardProcessing = CloseOnElementChoice; // Drive
	
	Refs = New Array;
	For Each Ref In SelectedRows Do
		If Items.List.RowData(Ref).IsFolder Then
			Continue;
		EndIf;
		
		Refs.Add(Ref);
	EndDo;
	
	If Refs.Count() > 0 Then
		BankClassificatorSelection(Refs);
		Notify("RefreshAfterAdd");
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	CommonClientServer.MessageToUser(
		NStr("en = 'You can''t add the data to the classifier interactive.
		     |You should use the command ""Import classifier""'; 
		     |ru = 'Интерактивное добавление в классификатор не поддерживается.
		     |Воспользуйтесь командой ""Загрузить классификатор""';
		     |pl = 'Nie możesz dodać danych do interaktywnego klasyfikatora.
		     |Powinieneś użyć polecenia ""Importuj klasyfikator""';
		     |es_ES = 'Usted no puede añadir los datos al clasificador interactivo.
		     |Usted necesita utilizar el comando ""Importar el clasificador""';
		     |es_CO = 'Usted no puede añadir los datos al clasificador interactivo.
		     |Usted necesita utilizar el comando ""Importar el clasificador""';
		     |tr = 'Verileri, sınıflandırıcıya etkileşimli olarak ekleyemezsiniz. 
		     |""Sınıflandırıcıyı içe aktar"" komutunu kullanmalısınız.';
		     |it = 'Non è possibile aggiungere i dati per la classificazione interattiva.
		     |tDovreste usare il comando ""Importazione classificatore""';
		     |de = 'Sie können die Daten nicht zum Klassifikator interaktiv hinzufügen.
		     |Sie sollten den Befehl ""Klassifikator importieren"" verwenden'"));
	
EndProcedure

&AtServer
Procedure SwitchInactiveBanksVisibility(Visibility)
	
	Items.FormShowInactiveBanks.Check = Visibility;
	
	CommonClientServer.SetDynamicListFilterItem(
			List, "OutOfBusiness", False, , , Not Visibility);
			
EndProcedure

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
