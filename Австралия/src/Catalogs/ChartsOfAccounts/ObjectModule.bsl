#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CurrentTypeOfEntries = Common.ObjectAttributeValue(Ref, "TypeOfEntries");
	
	If Not IsNew() And ValueIsFilled(CurrentTypeOfEntries) And TypeOfEntries <> CurrentTypeOfEntries Then
			
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	AccountingEntriesTemplates.Ref AS Ref
		|FROM
		|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
		|WHERE
		|	AccountingEntriesTemplates.ChartOfAccounts = &ChartOfAccounts";
		
		Query.SetParameter("ChartOfAccounts", Ref);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			ErrorMessage = NStr("en = 'Cannot change ""Type of entries"". The Chart of accounts is already applied to Accouting entries templates.'; ru = 'Не удалось изменить ""Тип проводок"". План счетов уже применяется к шаблонам бухгалтерских проводок.';pl = 'Nie można zmienić ""Typu wpisów"". Plan kont jest już zastosowany do szablonów wpisów księgowych.';es_ES = 'No se puede cambiar el ""Tipo de entradas de diario"". El diagrama de cuentas ya se aplica a las plantillas de entradas contables.';es_CO = 'No se puede cambiar el ""Tipo de entradas de diario"". El diagrama de cuentas ya se aplica a las plantillas de entradas contables.';tr = '""Giriş türü"" değiştirilemiyor. Hesap planı, Muhasebe girişi şablonlarına uygulanmış durumda.';it = 'Impossibile modificare ""Tipo di voci"". Il piano dei conti è già applicato ai modelli di voci di contabilità.';de = 'Fehler beim Ändern von ""Buchungstyp"". Der Kontenplan ist bereits für Buchungsvorlagen verwendet.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "TypeOfEntries", Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ChartOfAccounts = Enums.ChartsOfAccounts.MasterChartOfAccounts;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not CheckDescriptionIsUnique(Description) Then
		
		ErrorTemplate = NStr("en = 'Name must be unique. Item ""%1"" already exists. Specify another name. Then try again.'; ru = 'Имя должно быть уникальным. Элемент ""%1"" уже существует. Укажите другое имя и повторите попытку.';pl = 'Nazwa powinna być unikalna. Element ""%1"" już istnieje. Wybierz inną nazwę. Zatem spróbuj ponownie.';es_ES = 'El nombre debe ser único. El artículo ""%1"" ya existe. Especifica otro nombre. Inténtalo de nuevo.';es_CO = 'El nombre debe ser único. El artículo ""%1"" ya existe. Especifica otro nombre. Inténtalo de nuevo.';tr = 'Ad benzersiz olmalıdır. ""%1"" öğesi zaten mevcut. Başka bir ad belirtip tekrar deneyin.';it = 'Il nome deve essere univoco. L''elemento ""%1"" esiste già. Indicare un altro nome, poi riprovare.';de = 'Name muss einzigartig sein. Position ""%1"" besteht bereits. Geben Sie einen anderen Namen ein. Dann versuchen Sie erneut.'");
		ErrorMessage  = StrTemplate(ErrorTemplate, Description);
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "Description", Cancel);
		
	EndIf;
	
EndProcedure

Procedure OnReadPresentationsAtServer(Object) Export
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion

#Region Private

Function CheckDescriptionIsUnique(CurrentObjectDescription)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	COUNT(DISTINCT ChartsOfAccounts.Ref) AS RefCount
	|FROM
	|	Catalog.ChartsOfAccounts AS ChartsOfAccounts
	|WHERE
	|	ChartsOfAccounts.Description = &Description";
	
	Query.SetParameter("Description", CurrentObjectDescription);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() And SelectionDetailRecords.RefCount > 1 Then
		Return False;				
	EndIf;

	Return True;
	
EndFunction

#EndRegion

#EndIf