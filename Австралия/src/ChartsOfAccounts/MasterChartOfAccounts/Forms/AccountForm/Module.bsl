
#Region Variables

&AtClient
Var ArrayRowCompany;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChartOfAccountsBefore = CurrentObject.ChartOfAccounts;
	
	CompaniesBeforeValueTable = Object.Companies.Unload();
	ValueToFormAttribute(CompaniesBeforeValueTable, "CompaniesBefore");
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	ChartOfAccountsBefore = Object.ChartOfAccounts;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Object.Companies.Count() = 0 And DriveServer.IsRestrictedByCompany() Then
		
		ErrorMessage = NStr("en = 'Empty companies list is not allowed!'; ru = 'Заполните список организаций.';pl = 'Pusta lista firm nie jest dozwolona!';es_ES = 'No se permite una lista de empresas vacía.';es_CO = 'No se permite una lista de empresas vacía.';tr = 'Boş iş yeri listesine izin verilmez!';it = 'Non è concesso un elenco aziende vuoto!';de = 'Leere Firmenliste ist nicht gestattet!'");
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "AllowedCompanies", Cancel);
		
	EndIf;
	
	If Not ChartsOfAccounts.MasterChartOfAccounts.CheckCodeIsUnique(
		Object.Ref,
		Object.Code,
		Object.ChartOfAccounts) Then
		
		ErrorTemplate = NStr("en = 'The value ""%1"" of the field ""Code"" is not unique.'; ru = 'Значение ""%1"" поля ""Код"" уже существует.';pl = 'Wartość ""%1"" pola ""Kod"" nie jest unikalna.';es_ES = 'El valor ""%1"" del campo ""Código"" no es único.';es_CO = 'El valor ""%1"" del campo ""Código"" no es único.';tr = '""Kod"" alanının ""%1"" değeri benzersiz değil.';it = 'Il valore ""%1"" del campo ""Codice"" non è univoco.';de = 'Der Wert ""%1"" des Felds ""Code"" ist nicht einzigartig.'");
		ErrorMessage  = StrTemplate(ErrorTemplate, Object.Code);
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "Object.Code", Cancel);
		
	EndIf;
	
	If Not ValueIsFilled(Object.Order) Then
		
		ErrorMessage = NStr("en = '""Sort order"" is a required field.'; ru = 'Заполните поле ""Порядок сортировки""';pl = 'Pole ""Kolejność sortowania"" jest wymagane.';es_ES = '""Clasificar el orden"" es un campo obligatorio.';es_CO = '""Clasificar el orden"" es un campo obligatorio.';tr = '""Sıralama"" zorunlu alandır.';it = '""Ordinamento"" è un campo richiesto.';de = '""Sortierreihenfolge"" ist ein Pflichtfeld.'");
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "Object.Order", Cancel);
		
	EndIf;
	
	ModifiedAttributes	= DriveServer.GetModifiedAttributes(CurrentObject, False);
	ModifiedCompanies	= DriveServer.GetModifiedTabularSectionAttributes(CurrentObject, "Companies");
	CheckParent			= (ModifiedAttributes.Find("Parent") <> Undefined);
	CheckPeriod			= (ModifiedAttributes.Find("StartDate") <> Undefined Or ModifiedAttributes.Find("EndDate") <> Undefined);
	
	ChartsOfAccounts.MasterChartOfAccounts.CheckActivityPeriod(CurrentObject, CheckParent, CheckPeriod, ModifiedCompanies, Cancel);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ChartOfAccountsBefore = Object.ChartOfAccounts;
	
	CompaniesBeforeValueTable = Object.Companies.Unload();
	ValueToFormAttribute(CompaniesBeforeValueTable, "CompaniesBefore");
	
	HasRightToEdit = AccessRight("Update", Metadata.ChartsOfAccounts.MasterChartOfAccounts);
	
	Items.AllowedCompanies.Enabled = HasRightToEdit;
	
	AllowedCompaniesTable = ChartsOfAccounts.MasterChartOfAccounts.SelectAllowedCompaniesFromTable(Object.Companies.Unload());
	AllowedCompanies.Load(AllowedCompaniesTable);
	
	CompaniesCount = Object.Companies.Count();
	
	HasInaccessibleOrganizations = (CompaniesCount <> AllowedCompanies.Count());
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetAttributesBefore();
	FormManagement();
	
	ArrayRowCompany = New Array;
	
	For Each Row In Object.Companies Do
		ArrayRowCompany.Add(Row.Company);
	EndDo;
	
	RenumerateTable(AllowedCompanies);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.ChartOfAccounts) Then
		StandardProcessing = False;
		ErrorMessage = NStr("en = 'Chart of accounts is required.'; ru = 'Укажите план счетов.';pl = 'Plan kont jest wymagany.';es_ES = 'Se requiere un diagrama de cuentas.';es_CO = 'Se requiere un diagrama de cuentas.';tr = 'Hesap planı gerekli.';it = 'È richiesto il piano dei conti.';de = 'Kontoplan ist ein Pflichtfeld.'" );
		DriveClient.ShowMessageAboutError(ThisObject, ErrorMessage, , , "Object.ChartOfAccounts");
		
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FixedSettings = New DataCompositionSettings;
	
	FilterItem = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ChartOfAccounts");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Object.ChartOfAccounts;
	FilterItem.Use = True;
	
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FilterAndGroup = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterAndGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	FilterItem = FilterAndGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Ref");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.RightValue = Object.Ref;
	FilterItem.Use = True;
	
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FilterItem = FilterAndGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("StartDate");
	FilterItem.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	FilterItem.RightValue = Object.StartDate;
	FilterItem.Use = True;
	
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FilterOrGroup = FilterAndGroup.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterOrGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterOrGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("EndDate");
	FilterItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
	FilterItem.RightValue = ?(Object.EndDate = Date(1,1,1), Object.StartDate, Object.EndDate);
	FilterItem.Use = True;
	
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
	FilterItem = FilterOrGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("EndDate");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Date(1,1,1);
	FilterItem.Use = True;
	
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FormParameters = New Structure;
	FormParameters.Insert("FixedSettings", FixedSettings);
	
	OpenForm("ChartOfAccounts.MasterChartOfAccounts.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

&AtClient
Procedure UseAnalyticalDimensionsOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
		And Object.UseAnalyticalDimensions <> UseAnalyticalDimensionsBefore Then
		
		EntriesInfo = CheckEntriesAtServer();
		
		If EntriesInfo.Exist Then
			
			If EntriesInfo.Allowed Then
				
				ShowQueryBox(
					New NotifyDescription("CheckingExistEntriesEnd", ThisObject, New Structure("Attribute", Item.Name)),
					ExistEntriesQueryText(Item.Name, Object[Item.Name]),
					QuestionDialogMode.YesNo);
				
			Else
				
				Object.UseAnalyticalDimensions = Not Object.UseAnalyticalDimensions;
				
				ItemName = NStr("en = 'Analytical dimensions'; ru = 'Аналитические измерения';pl = 'Wymiary analityczne';es_ES = 'Dimensiones analíticas';es_CO = 'Dimensiones analíticas';tr = 'Analitik boyutlar';it = 'Dimensioni analitiche';de = 'Analytische Messungen'");
				OptionName = NStr("en = 'Allow to change analytical dimension settings if account has entries'; ru = 'Разрешить изменять настройки аналитических измерений, если есть проводки по счету';pl = 'Zezwól na zmianę ustawień wymiaru analitycznego, jeśli konto ma wpisy';es_ES = 'Permitir cambiar las configuraciones de la dimensión analítica si la cuenta tiene entradas de diario';es_CO = 'Permitir cambiar las configuraciones de la dimensión analítica si la cuenta tiene entradas de diario';tr = 'Hesapta girişler varsa analitik boyut ayarlarını değiştirmeye izin ver';it = 'Permette di modificare le impostazioni della dimensione analitica se il conto presenta delle voci';de = 'Ändern von analytischen Messungen gestatten, wenn das Konto Buchungen hat'");
				ShowMessageExistEntries(ItemName, OptionName);
				
			EndIf;
			
		ElsIf EntriesInfo.ExistTemplates Then
			
			ShowQueryBox(
				New NotifyDescription("CheckingExistEntriesEnd", ThisObject, New Structure("Attribute", Item.Name)),
				ExistTemplatesQueryText(),
				QuestionDialogMode.YesNo);
		Else
			
			Items.AnalyticalDimensionsSet.Visible	= Object.UseAnalyticalDimensions;
			Items.AnalyticalDimensions.Visible		= Object.UseAnalyticalDimensions;
			
		EndIf;
		
	Else
		
		Items.AnalyticalDimensionsSet.Visible	= Object.UseAnalyticalDimensions;
		Items.AnalyticalDimensions.Visible		= Object.UseAnalyticalDimensions;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AnalyticalDimensionsSetOnChangeAtServer()
	
	AnalyticalDimensions = Object.AnalyticalDimensionsSet.AnalyticalDimensions;
	Object.AnalyticalDimensions.Load(AnalyticalDimensions.Unload());
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionsSetOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
		And ValueIsFilled(AnalyticalDimensionsSetBefore)
		And Object.AnalyticalDimensionsSet <> AnalyticalDimensionsSetBefore Then
		
		EntriesInfo = CheckEntriesAtServer();
		
		If EntriesInfo.Exist Then
			
			NewAnalyticalDimensionsSet		 = Object.AnalyticalDimensionsSet;
			Object.AnalyticalDimensionsSet	 = AnalyticalDimensionsSetBefore;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("NewAnalyticalDimensionsSet", NewAnalyticalDimensionsSet);
			
			If EntriesInfo.Allowed Then
				
				ShowQueryBox(
					New NotifyDescription("CheckingChangingAnalyticalDimensionsSetEnd", ThisObject, AdditionalParameters),
					ExistEntriesQueryText(Item.Name, False),
					QuestionDialogMode.YesNo);
				
			Else
				
				ItemName = NStr("en = 'Analytical dimension set'; ru = 'Набор аналитических измерений';pl = 'Zestaw wymiarów analitycznych';es_ES = 'Conjunto de dimensión analítica';es_CO = 'Conjunto de dimensión analítica';tr = 'Analitik boyut kümesi';it = 'Set dimensione analitica';de = 'Satz von analytischen Messungen'");
				OptionName = NStr("en = 'Allow to change analytical dimension settings if account has entries'; ru = 'Разрешить изменять настройки аналитических измерений, если есть проводки по счету';pl = 'Zezwól na zmianę ustawień wymiaru analitycznego, jeśli konto ma wpisy';es_ES = 'Permitir cambiar las configuraciones de la dimensión analítica si la cuenta tiene entradas de diario';es_CO = 'Permitir cambiar las configuraciones de la dimensión analítica si la cuenta tiene entradas de diario';tr = 'Hesapta girişler varsa analitik boyut ayarlarını değiştirmeye izin ver';it = 'Permette di modificare le impostazioni della dimensione analitica se il conto presenta delle voci';de = 'Ändern von analytischen Messungen gestatten, wenn das Konto Buchungen hat'");
				ShowMessageExistEntries(ItemName, OptionName, False);
				
			EndIf;
			
		ElsIf EntriesInfo.ExistTemplates Then
			
			NewAnalyticalDimensionsSet		 = Object.AnalyticalDimensionsSet;
			Object.AnalyticalDimensionsSet	 = AnalyticalDimensionsSetBefore;
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("NewAnalyticalDimensionsSet", NewAnalyticalDimensionsSet);
			
			ShowQueryBox(
				New NotifyDescription("CheckingChangingAnalyticalDimensionsSetEnd", ThisObject, AdditionalParameters),
				ExistTemplatesQueryText(),
				QuestionDialogMode.YesNo);
			
		Else
			
			Object.AnalyticalDimensions.Clear();
			AnalyticalDimensionsSetOnChangeAtServer();
			
			AnalyticalDimensionsSetBefore = Object.AnalyticalDimensionsSet;
			
		EndIf;
		
	Else
		
		Object.AnalyticalDimensions.Clear();
		AnalyticalDimensionsSetOnChangeAtServer();
		
		AnalyticalDimensionsSetBefore = Object.AnalyticalDimensionsSet;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseQuantityOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
		And Object.UseQuantity <> UseQuantityBefore Then
		
		EntriesInfo = CheckEntriesWithQuantityAtServer();
		
		If EntriesInfo.Exist Then
			
			If EntriesInfo.Allowed Then
				
				ShowQueryBox(New NotifyDescription("CheckingExistEntriesWithQuantityEnd", ThisObject),
					ExistEntriesQueryText(Item.Name, Object[Item.Name]),
					QuestionDialogMode.YesNo);
					
			Else
				
				Object.UseQuantity = Not Object.UseQuantity;
				
				ItemName = NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'");
				OptionName = NStr("en = 'Allow to change quantity settings if account has entries'; ru = 'Разрешить изменять настройки количества, если есть проводки по счету';pl = 'Zezwól na zmianę ustawień ilości, jeśli konto ma wpisy';es_ES = 'Permitir cambiar las configuraciones de la cantidad si la cuenta tiene entradas de diario';es_CO = 'Permitir cambiar las configuraciones de la cantidad si la cuenta tiene entradas de diario';tr = 'Hesapta girişler varsa miktar ayarlarını değiştirmeye izin ver';it = 'Permette di modificare le impostazioni di quantità se il conto presenta delle voci';de = 'Ändern von Einstellungen von Menge gestatten, wenn das Konto Buchungen hat'");
				ShowMessageExistEntries(ItemName, OptionName);
				
			EndIf;
			
		ElsIf EntriesInfo.ExistTemplates Then
			
			ShowQueryBox(
				New NotifyDescription("CheckingExistEntriesEnd", ThisObject, New Structure("Attribute", Item.Name)),
				ExistTemplatesQueryText(),
				QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChartOfAccountsOnChange(Item)
	
	If Not CheckChartOfAccountsParent() Then
		
		ErrorTemplate = NStr("en = 'The ""Subordinate to"" field contains the account that is not included in ""%1"". The field will be cleared. Continue?'; ru = 'Поле ""Подчинен счету"" содержит счет, который не входит в ""%1"". Поле будет очищено. Продолжить?';pl = 'Pole ""Podporządkowany"" obejmuje konto, które nie jest włączone w ""%1"". Pole zostanie wyczyszczone. Kontynuować?';es_ES = 'El campo ""Subordinar a"" contiene la cuenta que no está incluida en ""%1"". El campo se borrará. ¿Continuar?';es_CO = 'El campo ""Subordinar a"" contiene la cuenta que no está incluida en ""%1"". El campo se borrará. ¿Continuar?';tr = '""Üst hesap"" alanı, ""%1""e dahil olmayan bir hesap içeriyor. Alan temizlenecek. Devam edilsin mi?';it = 'Il campo ""subordinato a"" contiene un conto che non è incluso in ""%1"". Il campo sarà cancellato, continuare?';de = 'Das Feld ""Untergeordnet dem"" enthält ein Konto nicht im Bestand von ""%1"". Das Feld wird entleert. Weiter?'");	
		ErrorMessage  = StrTemplate(ErrorTemplate, Object.ChartOfAccounts);
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("AfterQueryAboutChartOfAccountsClose", ThisObject);
		ShowQueryBox(Notification, ErrorMessage, Mode);
		Return;
		
	EndIf;
	
	ChartOfAccountsBefore = Object.ChartOfAccounts;
	
	ChartOfAccountsOnChangeAtServer();
	FormManagement();
	
EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
		And Object.Currency <> CurrencyBefore Then
		
		EntriesInfo = CheckEntriesWithCurrencyAtServer();
		
		If EntriesInfo.Exist Then
			
			ShowQueryBox(New NotifyDescription("CheckingExistEntriesWithCurrencyEnd", ThisObject),
				ExistEntriesQueryText(Item.Name, Object[Item.Name]),
				QuestionDialogMode.YesNo);
			
		ElsIf EntriesInfo.ExistTemplates Then
			
			ShowQueryBox(
				New NotifyDescription("CheckingExistEntriesEnd", ThisObject, New Structure("Attribute", Item.Name)),
				ExistTemplatesQueryText(),
				QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersCompanies

&AtClient
Procedure CompaniesOnActivateRow(Item)
	
	CurrentData = Items.AllowedCompanies.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.AllowedCompaniesCompany.ReadOnly = ArrayRowCompany.Find(CurrentData.Company) <> Undefined;
	
EndProcedure

&AtClient
Procedure CompaniesBeforeDeleteRow(Item, Cancel)
	
	If Object.Ref.IsEmpty() Then
		Return;
	EndIf;
	
	CurrentData = Items.AllowedCompanies.CurrentData;
	
	CompaniesBeforeDeleteRowAtServer(CurrentData.Company, Cancel);
	
EndProcedure

&AtClient
Procedure CompaniesCompanyOnChange(Item)
	
	ClearMessages();
	
	CurrentData = Items.AllowedCompanies.CurrentData;
	CompanyCurrent	= CurrentData.Company;
	CurrentRow		= Items.AllowedCompanies.CurrentRow;
	
	For Each CompanyRow In AllowedCompanies Do
		
		If CompanyRow.Company = CompanyCurrent And CurrentRow <> CompanyRow.GetID() Then
			
			MessageTemplate	= NStr("en = 'Cannot add %1. This company was already added in line %2.'; ru = 'Не удалось добавить %1. Эта организация уже добавлена в строку %2.';pl = 'Nie można dodać %1. Ta firma już została dodana w wierszu %2.';es_ES = 'No se puede añadir%1. Esta empresa ya estaba añadida en la línea%2.';es_CO = 'No se puede añadir%1. Esta empresa ya estaba añadida en la línea%2.';tr = '%1 eklenemiyor. Bu iş yeri %2 satırında zaten ekli.';it = 'Impossibile aggiungere %1. Questa azienda è stata già aggiunta nella riga %2.';de = 'Fehler beim Hinzufügen von %1. Diese Firma ist bereits in der Zeile %2 hinzugefügt.'");
			MessageText		= StrTemplate(MessageTemplate, CompanyRow.Company, CompanyRow.LineNumber);
			FieldName		= StrTemplate("AllowedCompanies[%1].Company", AllowedCompanies.IndexOf(CompanyRow));
			
			CommonClientServer.MessageToUser(MessageText, , FieldName);
			
			CurrentData.Company = Undefined;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterQueryAboutChartOfAccountsClose(Result, Parameters) Export
	
	If Result = DialogReturnCode.No Then
		Object.ChartOfAccounts = ChartOfAccountsBefore;
		Return;
	EndIf;
	
	Object.Parent = Undefined;
	ChartOfAccountsBefore = Object.ChartOfAccounts;
	
	ChartOfAccountsOnChangeAtServer();
	FormManagement();
	
EndProcedure

&AtServer
Function CheckChartOfAccountsParent()
	
	If ValueIsFilled(Object.Parent) Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	MasterChartOfAccounts.Ref AS Ref
		|FROM
		|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
		|WHERE
		|	MasterChartOfAccounts.Ref = &Ref
		|	AND MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts";
		
		Query.SetParameter("ChartOfAccounts", Object.ChartOfAccounts);
		Query.SetParameter("Ref", Object.Parent);
		
		QueryResult = Query.Execute();
		
		Return Not QueryResult.IsEmpty();
		
	Else
		
		Return True;
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function GetChartOfAccountsAttributesAtServer(ChartOfAccounts)

	Result = New Structure("UseQuantity, UseAnalyticalDimensions");
	
	FillPropertyValues(Result, ChartOfAccounts);
	
	Return Result;

EndFunction

&AtClient
Procedure FormManagement()

	If HasInaccessibleOrganizations Then
		ReadOnly = True;
		Items.AllowedCompanies.ReadOnly = True;
	EndIf;
	
	If ValueIsFilled(Object.ChartOfAccounts) Then
		
		ChartOfAccountsAttributes = GetChartOfAccountsAttributesAtServer(Object.ChartOfAccounts);
		
		Items.UseQuantity.Visible				= ChartOfAccountsAttributes.UseQuantity;
		Items.UseAnalyticalDimensions.Visible	= ChartOfAccountsAttributes.UseAnalyticalDimensions;
		Items.AnalyticalDimensionsSet.Visible	= Object.UseAnalyticalDimensions;
		Items.AnalyticalDimensions.Visible		= Object.UseAnalyticalDimensions;
		
	Else
		
		Items.UseQuantity.Visible				= False;
		Items.UseAnalyticalDimensions.Visible	= False;
		Items.AnalyticalDimensionsSet.Visible	= False;
		Items.AnalyticalDimensions.Visible		= False;
		
	EndIf;

EndProcedure

&AtServer
Function CheckEntriesAtServer()

	Return New Structure("Exist, Allowed, ExistTemplates", 
		WorkWithArbitraryParameters.CheckExistRegisterEntries(Object.Ref),
		Object.ChartOfAccounts.AllowToChangeAnalyticalDimensionsIfAccountHasEntries,
		WorkWithArbitraryParameters.CheckExistTemplates(Object.Ref));

EndFunction

&AtServer
Function CheckEntriesWithQuantityAtServer()

	Return New Structure("Exist, Allowed, ExistTemplates", 
		WorkWithArbitraryParameters.CheckExistRegisterEntries(Object.Ref),
		Common.ObjectAttributeValue(Object.ChartOfAccounts, "AllowToChangeQuantitySettingsIfAccountHasEntries"),
		WorkWithArbitraryParameters.CheckExistTemplates(Object.Ref));

EndFunction

&AtClient
Procedure CheckingExistEntriesEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Items.AnalyticalDimensionsSet.Visible	= Object.UseAnalyticalDimensions;
		Items.AnalyticalDimensions.Visible		= Object.UseAnalyticalDimensions;
		
	ElsIf ClosingResult = DialogReturnCode.No Then
		
		Object[AdditionalParameters.Attribute] = Not Object[AdditionalParameters.Attribute];
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckingExistEntriesWithQuantityEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.No Then
		
		Object.UseQuantity = Not Object.UseQuantity;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckingChangingAnalyticalDimensionsSetEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.AnalyticalDimensionsSet = AdditionalParameters.NewAnalyticalDimensionsSet;
		
		Object.AnalyticalDimensions.Clear();
		AnalyticalDimensionsSetOnChangeAtServer();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChartOfAccountsOnChangeAtServer()

	Object.UseQuantity				= Object.UseQuantity And Object.ChartOfAccounts.UseQuantity;
	Object.UseAnalyticalDimensions	= Object.UseAnalyticalDimensions And Object.ChartOfAccounts.UseAnalyticalDimensions;

EndProcedure

&AtClient
Procedure AllowedCompaniesOnChange(Item)
	
	CurrentData = Item.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.LineNumberForUser) Then
		CurrentData.LineNumberForUser = AllowedCompanies.Count();
	EndIf;
	
	If ValueIsFilled(CurrentData.LineNumber) Then
		RowObject = Object.Companies[CurrentData.LineNumber - 1];
	Else
		RowObject = Object.Companies.Add();
		CurrentData.LineNumber = RowObject.LineNumber;
	EndIf;
	
	FillPropertyValues(RowObject, CurrentData);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure AllowedCompaniesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = Clone;
EndProcedure

&AtServer
Function CheckEntriesWithCurrencyAtServer()
	
	Return New Structure("Exist, ExistTemplates",
		WorkWithArbitraryParameters.CheckExistRegisterEntries(Object.Ref),
		WorkWithArbitraryParameters.CheckExistTemplatesWithCurrencyFlag(Object.Ref));
	
EndFunction

&AtClient
Procedure CheckingExistEntriesWithCurrencyEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.No Then
		
		Object.Currency = Not Object.Currency;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CompaniesBeforeDeleteRowAtServer(Company, Cancel)

	If CompaniesBefore.FindRows(New Structure("Company", Company)).Count() Then
	
		QueryResult = WorkWithArbitraryParameters.GetExistTemplatesWithCompany(Object.Ref, Company);
		
		If Not QueryResult.IsEmpty() Then
			
			QuerySelection = QueryResult.Select();
			While QuerySelection.Next() Do
				MessageText = NStr("en = 'Cannot delete ""%1"" from account. ""%2"" is applied to the account and company.'; ru = 'Не удалось удалить ""%1"" из счета. ""%2"" уже применяется к счету и организации.';pl = 'Nie można usunąć ""%1"" z konta. ""%2"" jest zastosowany dla konta i firmy.';es_ES = 'No se puede eliminar ""%1"" de la cuenta. ""%2 se aplica a la cuenta y a la empresa.';es_CO = 'No se puede eliminar ""%1"" de la cuenta. ""%2 se aplica a la cuenta y a la empresa.';tr = '""%1"" hesaptan silinemiyor. ""%2"", hesaba ve iş yerine uygulanıyor.';it = 'Impossibile eliminare ""%1"" dal conto. ""%2"" è applicato al conto e all''azienda.';de = 'Fehler beim Löschen von ""%1"" aus Konto. ""%2"" ist für das Konto und die Firma verwendet.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					Company,
					QuerySelection.Ref);
					
				CommonClientServer.MessageToUser(MessageText, , , , Cancel);
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If Not Cancel Then
		
		FoundRows = Object.Companies.FindRows(New Structure("Company", Company));
		
		Object.Companies.Delete(FoundRows[0]);
		
		For Each Row In AllowedCompanies Do
			
			If Row.Company = Company Then
				Continue;
			EndIf;
			
			FoundRows = Object.Companies.FindRows(New Structure("Company", Row.Company));
			Row.LineNumber = FoundRows[0].LineNumber;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Function ExistEntriesQueryText(AttributeName, Checked)

	If Checked Then
		QueryText = NStr("en = 'Account ""%1, %2"" is applied to accounting templates. It is recommended to review the accounting entries, accounting entries templates and accounting transaction templates where this account is applied and adjust them if needed. Continue?'; ru = 'Счет ""%1, %2"" применяется в шаблонах бухгалтерского учета. Рекомендуется просмотреть бухгалтерские проводки, шаблоны бухгалтерских проводок и шаблоны бухгалтерских операций, в которых применяется этот счет, и скорректировать их при необходимости. Продолжить?';pl = 'Konto ""%1, %2"" jest zastosowane do szablonów rachunkowości. Zaleca się przejrzenie wpisów księgowych, szablonów wpisów księgowych, gdzie to konto jest zastosowane i zmienić go w razie potrzeby. Kontynuować?';es_ES = 'La cuenta ""%1, %2"" se aplica a las plantillas contables. Se recomienda revisar las entradas contables, las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';es_CO = 'La cuenta ""%1, %2"" se aplica a las plantillas contables. Se recomienda revisar las entradas contables, las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';tr = '""%1, %2"" hesabı muhasebe şablonlarına uygulanıyor. Bu hesabın uygulandığı muhasebe girişlerini, muhasebe girişi şablonlarını ve muhasebe işlemi şablonlarını inceleyip gerekirse düzeltmeniz önerilir. Devam edilsin mi?';it = 'Il conto ""%1,%2"" è applicato ai modelli di conto. Si consiglia di rivedere le voci di contabilità, i modelli di voci di contabilità e i modelli di transazione di contabilità in cui è applicato questo conto e correggerli se necessario. Continuare?';de = 'Konto ""%1, %2"" ist für Buchhaltungsvorlagen verwendet. Es ist empfehlenswert die Buchungen, Buchungsvorlagen und Buchhaltungstransaktionsvorlagen wo dieses Konto verwendet ist zu überprüfen und sie ggf. anzupassen. Weiter?'");
	Else
		
		If AttributeName = "UseAnalyticalDimensions" Then
			QueryText = NStr("en = 'Account ""%1, %2"" is applied to accounting templates. All details on analytical dimensions will be removed from the accounting entries. It is recommended to review the accounting entries templates and accounting transaction templates where this account is applied and adjust them if needed. Continue?'; ru = 'Счет ""%1, %2"" применяется в шаблонах бухгалтерского учета. Вся информация об аналитических измерениях будет удалена из бухгалтерских проводок. Рекомендуется просмотреть шаблоны бухгалтерских проводок и шаблоны бухгалтерских операций, в которых применяется этот счет, и скорректировать их при необходимости. Продолжить?';pl = 'Konto ""%1, %2"" jest zastosowane do szablonów rachunkowości. Wszystkie szczegóły w wymiarach analitycznych zostaną usunięte ze wpisów księgowych. Zaleca się przejrzenie szablonów wpisów księgowych i transakcji księgowych, gdzie to konto jest zastosowane i zmienić je w razie potrzeby. Kontynuować?';es_ES = 'La cuenta ""%1, %2"" se aplica a las plantillas contables. Todos los detalles de las dimensiones analíticas se eliminarán de las entradas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';es_CO = 'La cuenta ""%1, %2"" se aplica a las plantillas contables. Todos los detalles de las dimensiones analíticas se eliminarán de las entradas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';tr = '""%1, %2"" hesabı muhasebe şablonlarına uygulanıyor. Analitik boyutlarla ilgili tüm bilgiler muhasebe girişlerinden çıkarılacak. Bu hesabın uygulandığı muhasebe girişi şablonlarını ve muhasebe işlemi şablonlarını inceleyip gerekirse düzeltmeniz önerilir. Devam edilsin mi?';it = 'Il conto ""%1,%2"" è applicato ai modelli di contabilità. Tutti i dettagli sulle dimensioni analitiche saranno rimossi dalle voci di contabilità. Si consiglia di rivedere i modelli di voci di contabilità e i modelli di transazione di contabilità in cui questo conto è applicato e correggerli se necessario. Continuare?';de = 'Konto ""%1, %2"" ist für Buchhaltungsvorlagen verwendet. Alle Details von analytischen Messungen werden aus den Buchungen entfernt. Es ist empfehlenswert die Buchungen, Buchungsvorlagen und Buchhaltungstransaktionsvorlagen wo dieses Konto verwendet ist zu überprüfen und sie ggf. anzupassen. Weiter?'");
		ElsIf AttributeName = "AnalyticalDimensionsSet" Then
			QueryText = NStr("en = 'Account ""%1, %2"" is applied to accounting templates. The analytical dimensions that the previous set includes while the current set excludes will be removed form the existing accounting entries. It is recommended to review the accounting entries, accounting entries templates, and accounting transaction templates where this account is applied and adjust them if needed. Continue?'; ru = 'Счет ""%1, %2"" применяется в шаблонах бухгалтерского учета. Аналитические измерения, которые входят в предыдущий набор, но не входят в текущий набор, будут удалены из бухгалтерских проводок. Рекомендуется просмотреть бухгалтерские проводки, шаблоны бухгалтерских проводок и шаблоны бухгалтерских операций, в которых применяется этот счет, и скорректировать их при необходимости. Продолжить?';pl = 'Konto ""%1, %2"" jest zastosowane do szablonów rachunkowości. Wymiary analityczne, które zawiera poprzedni zestaw, podczas gdy bieżący zestaw wyklucza, zostaną usunięte z istniejących wpisów księgowych. Zaleca się przejrzenie wpisów księgowych, szablonów wpisów księgowych i szablonów transakcji księgowych, gdzie to konto jest zastosowane i zmienić je. Kontynuować?';es_ES = 'La cuenta ""%1, ""%2 se aplica a las plantillas contables. Las dimensiones analíticas que el conjunto anterior incluye mientras que el conjunto actual excluye se eliminarán de las entradas contables existentes. Se recomienda revisar las entradas contables, las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';es_CO = 'La cuenta ""%1, ""%2 se aplica a las plantillas contables. Las dimensiones analíticas que el conjunto anterior incluye mientras que el conjunto actual excluye se eliminarán de las entradas contables existentes. Se recomienda revisar las entradas contables, las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';tr = '""%1, %2"" hesabı muhasebe şablonlarına uygulanıyor. Mevcut kümenin içermeyip önceki kümenin içerdiği analitik boyutlar var olan muhasebe girişlerinden çıkarılacak. Bu hesabın uygulandığı muhasebe girişlerini, muhasebe girişi şablonlarını ve muhasebe işlemi şablonlarını gözden geçirip, gerekirse düzeltmeniz önerilir. Devam edilsin mi?';it = 'Il conto ""%1, %2"" è applicato ai modelli di contabilità- Le dimensioni analitiche incluse nel set precedente ma escluse in quello corrente saranno rimosse dalle voci di contabilità esistenti. Si consiglia di rivedere le voci di contabilità, modelli di voci di contabilità e modelli di transazioni di contabilità in cui è applicato questo conto e correggerli se necessario. Continuare?';de = 'Konto ""%1, %2"" ist für Buchhaltungsvorlagen verwendet. Die analytischen Messungen die der vorherige Satz enthält und das aktuelle Satz ausschließt, werden aus den bestehenden Buchungen entfernt. Es ist empfehlenswert die Buchungen, Buchungsvorlagen und Buchhaltungstransaktionsvorlagen wo dieses Konto verwendet ist zu überprüfen und sie ggf. anzupassen. Weiter?'");
		ElsIf AttributeName = "UseQuantity" Then
			QueryText = NStr("en = 'Account ""%1, %2"" is applied to accounting templates. All existing quantity details will be removed from the accounting entries. It is recommended to review the accounting entries templates and accounting transaction templates where this account is applied and adjust them if needed. Continue?'; ru = 'Счет ""%1, %2"" применяется в шаблонах бухгалтерского учета. Вся информация о количестве будет удалена из бухгалтерских проводок. Рекомендуется просмотреть шаблоны бухгалтерских проводок и шаблоны бухгалтерских операций, в которых применяется этот счет, и скорректировать их при необходимости. Продолжить?';pl = 'Konto ""%1, %2"" jest zastosowane do szablonów rachunkowości. Wszystkie szczegóły ilości zostaną usunięte ze wpisów księgowych. Zaleca się przejrzenie szablonów wpisów księgowych i transakcji księgowych, gdzie to konto jest zastosowane i zmienić je w razie potrzeby. Kontynuować?';es_ES = 'La cuenta ""%1,%2 "" se aplica a las plantillas contables. Todos los detalles de cantidad existentes se eliminarán de las entradas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';es_CO = 'La cuenta ""%1,%2 "" se aplica a las plantillas contables. Todos los detalles de cantidad existentes se eliminarán de las entradas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';tr = '""%1, %2"" hesabı muhasebe şablonlarına uygulanıyor. Tüm mevcut miktar bilgileri muhasebe girişlerinden çıkarılacak. Bu hesabın uygulandığı muhasebe girişi şablonlarını ve muhasebe işlemi şablonlarını inceleyip gerekirse düzeltmeniz önerilir. Devam edilsin mi?';it = 'Il conto ""%1,%2"" è applicato ai modelli di contabilità. Tutti i dettagli sulle dimensioni analitiche saranno rimossi dalle voci di contabilità. Si consiglia di rivedere i modelli di voci di contabilità e i modelli di transazione di contabilità in cui questo conto è applicato e correggerli se necessario. Continuare?';de = 'Konto ""%1, %2"" ist für Buchhaltungsvorlagen verwendet. Alle bestehenden Details über Menge werden aus den Buchungen entfernt. Es ist empfehlenswert die Buchungen, Buchungsvorlagen und Buchhaltungstransaktionsvorlagen wo dieses Konto verwendet ist zu überprüfen und sie ggf. anzupassen. Weiter?'");
		ElsIf AttributeName = "Currency" Then
			QueryText = NStr("en = 'Account ""%1, %2"" is applied to accounting templates. All existing currency details will be removed from the accounting entries. It is recommended to review the accounting entries templates and accounting transaction templates where this account is applied and adjust them if needed. Continue?'; ru = 'Счет ""%1, %2"" применяется в шаблонах бухгалтерского учета. Вся информация о валютах будет удалена из бухгалтерских проводок. Рекомендуется просмотреть шаблоны бухгалтерских проводок и шаблоны бухгалтерских операций, в которых применяется этот счет, и скорректировать их при необходимости. Продолжить?';pl = 'Konto ""%1, %2"" jest zastosowane do szablonów rachunkowości. Wszystkie szczegóły waluty zostaną usunięte ze wpisów księgowych. Zaleca się przejrzenie szablonów wpisów księgowych i transakcji księgowych, gdzie to konto jest zastosowane i zmienić je w razie potrzeby. Kontynuować?';es_ES = 'La cuenta ""%1,%2 "" se aplica a las plantillas contables. Todos los detalles de moneda existentes se eliminarán de las entradas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';es_CO = 'La cuenta ""%1,%2 "" se aplica a las plantillas contables. Todos los detalles de moneda existentes se eliminarán de las entradas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';tr = '""%1, %2"" hesabı muhasebe şablonlarına uygulanıyor. Tüm mevcut para birimi bilgileri muhasebe girişlerinden çıkarılacak. Bu hesabın uygulandığı muhasebe girişi şablonlarını ve muhasebe işlemi şablonlarını inceleyip gerekirse düzeltmeniz önerilir. Devam edilsin mi?';it = 'Il conto ""%1,%2"" è applicato ai modelli di contabilità. Tutti i dettagli sulle dimensioni analitiche saranno rimossi dalle voci di contabilità. Si consiglia di rivedere i modelli di voci di contabilità e i modelli di transazione di contabilità in cui questo conto è applicato e correggerli se necessario. Continuare?';de = 'Konto ""%1, %2"" ist für Buchhaltungsvorlagen verwendet. Alle bestehende Währungsdetails werden aus den Buchungen entfernt. Es ist empfehlenswert die Buchungen, Buchungsvorlagen und Buchhaltungstransaktionsvorlagen wo dieses Konto verwendet ist zu überprüfen und sie ggf. anzupassen. Weiter?'");
		EndIf;
		
	EndIf;
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		QueryText,
		Object.Code,
		Object.Description);
		
	Return QueryText;

EndFunction

&AtClient
Function ExistTemplatesQueryText()

	QueryText = NStr("en = 'Account ""%1, %2"" is applied to accounting templates. It is recommended to review the accounting entries templates and accounting transaction templates where this account is applied and adjust them if needed. Continue?'; ru = 'Счет ""%1, %2"" применяется в шаблонах бухгалтерского учета. Рекомендуется просмотреть шаблоны бухгалтерских проводок и шаблоны бухгалтерских операций, в которых применяется этот счет, и скорректировать их при необходимости. Продолжить?';pl = 'Konto ""%1, %2"" jest zastosowane do szablonów rachunkowości. Zaleca się przejrzenie szablonów wpisów księgowych i szablonów transakcji księgowych, gdzie to konto jest zastosowane i zmienić go w razie potrzeby. Kontynuować?';es_ES = 'La cuenta ""%1,%2 "" se aplica a las plantillas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';es_CO = 'La cuenta ""%1,%2 "" se aplica a las plantillas contables. Se recomienda revisar las plantillas de entradas contables y las plantillas de transacciones contables donde se aplica esta cuenta y ajustarlas si es necesario. ¿Continuar?';tr = '""%1, %2"" hesabı muhasebe şablonlarına uygulanıyor. Bu hesabın uygulandığı muhasebe girişi şablonlarını ve muhasebe işlemi şablonlarını inceleyip gerekirse düzeltmeniz önerilir. Devam edilsin mi?';it = 'Il conto ""%1,%2"" è applicato ai modelli di conto. Si consiglia di rivedere le voci di contabilità, i modelli di voci di contabilità e i modelli di transazione di contabilità in cui è applicato questo conto e correggerli se necessario. Continuare?';de = 'Konto %1, %2"" ist für Buchhaltungsvorlagen verwendet. Es ist empfehlenswert die Buchungsvorlagen und Buchhaltungstransaktionsvorlagen wo dieses Konto verwendet ist zu überprüfen und sie ggf. anzupassen. Weiter?'");
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		QueryText,
		Object.Code,
		Object.Description);
		
	Return QueryText;

EndFunction

&AtClient
Procedure ShowMessageExistEntries(ItemName, OptionName, IsBoolean = True)
	
	ClearMessages();
	
	If IsBoolean Then
		MessageText = NStr("en = 'Cannot change the ""%1"" option.
			|The account has entries and it is included in the chart of accounts where the ""%2"" checkbox is cleared.'; 
			|ru = 'Не удалось изменить опцию ""%1"".
			|По счету есть проводки, и он входит в план счетов, в котором не установлен флажок ""%2"".';
			|pl = 'Nie można zmienić opcji ""%1"".
			|Konto zawiera wpisy i jest włączone do planu kont, gdzie pole wyboru ""%2"" jest odznaczone.';
			|es_ES = 'No se ha podido cambiar la opción ""%1"".
			| La cuenta tiene entradas de diario y está incluida en el diagrama de cuentas cuando la casilla de verificación ""%2"" está desmarcada.';
			|es_CO = 'No se ha podido cambiar la opción ""%1"".
			| La cuenta tiene entradas de diario y está incluida en el diagrama de cuentas cuando la casilla de verificación ""%2"" está desmarcada.';
			|tr = '""%1"" seçeneği değiştirilemiyor.
			|Hesap girişler içeriyor ve ""%2"" onay kutusunun boş olduğu hesap planına dahil.';
			|it = 'Impossibile modificare l''opzione ""%1"". 
			|Il conto ha delle voci ed è incluso nel piano dei conti in cui la casella di controllo ""%2"" è deselezionata.';
			|de = 'Fehler beim Ändern der Option ""%1"".
			|Das Konto hat Buchungen und ist im Kontenplan, wo das Kontrollkästchen ""%2"" deaktiviert ist, eingeschlossen.'");
	Else
		MessageText = NStr("en = 'Cannot change ""%1"".
			|The account has entries and it is included in the chart of accounts where the ""%2"" checkbox is cleared.'; 
			|ru = 'Не удалось изменить ""%1"".
			|По счету есть проводки, и он входит в план счетов, в котором не установлен флажок ""%2"".';
			|pl = 'Nie można zmienić ""%1"" .
			|Konto zawiera wpisy i jest włączone do planu kont, gdzie pole wyboru ""%2"" jest odznaczone.';
			|es_ES = 'No se ha podido cambiar ""%1"".
			|La cuenta tiene entradas de diario y está incluida en el diagrama de cuentas cuando la casilla de verificación ""%2"" está desmarcada.';
			|es_CO = 'No se ha podido cambiar ""%1"".
			|La cuenta tiene entradas de diario y está incluida en el diagrama de cuentas cuando la casilla de verificación ""%2"" está desmarcada.';
			|tr = '""%1"" değiştirilemiyor.
			|Hesap girişler içeriyor ve ""%2"" onay kutusunun boş olduğu hesap planına dahil.';
			|it = 'Impossibile modificare ""%1"".
			|Il conto ha delle voci ed è incluso nel piano dei conti in cui la casella di controllo ""%2"" è deselezionata.';
			|de = 'Fehler beim Ändern von ""%1"". 
			|Das Konto hat Buchungen und ist im Kontenplan, wo das Kontrollkästchen ""%2""deaktiviert ist, eingeschlossen.'");
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ItemName, OptionName);
	
	CommonClientServer.MessageToUser(MessageText);
	
EndProcedure

&AtClient
Procedure SetAttributesBefore()

	AnalyticalDimensionsSetBefore	= Object.AnalyticalDimensionsSet;
	CurrencyBefore					= Object.Currency;
	UseAnalyticalDimensionsBefore	= Object.UseAnalyticalDimensions;
	UseQuantityBefore				= Object.UseQuantity;

EndProcedure

&AtClient
Procedure AllowedCompaniesAfterDeleteRow(Item)
	RenumerateTable(AllowedCompanies);
EndProcedure

&AtClientAtServerNoContext
Procedure RenumerateTable(Table)
	
	LineNumber = 1;
	For Each Row In Table Do
		
		Row.LineNumberForUser = LineNumber;
		LineNumber = LineNumber + 1;
		
	EndDo;
	
EndProcedure
#EndRegion