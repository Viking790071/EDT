#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
	TypeOfEntries = Object.TypeOfEntries;
	UseAnalyticalDimensions = Object.UseAnalyticalDimensions;
	UseQuantity = Object.UseQuantity;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	If WriteParameters.Property("Close") Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagement();
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If ValueIsFilled(Object.Ref) Then
		
		NeededValuesArray = New Array;
		NeededValuesArray.Add("UseAnalyticalDimensions");
		NeededValuesArray.Add("UseQuantity");
		
		OldValues = GetObjectOldValues(NeededValuesArray);
		
		If Not WriteParameters.Property("NoCheckAnalyticalDimensions")
			And Not Object.UseAnalyticalDimensions
			And OldValues.UseAnalyticalDimensions Then
			
			AdditionalParameters = WriteParameters;
			AdditionalParameters.Insert("CheckingAttribute", "AnalyticalDimensions");
			
			CheckingExistEntriesEnd(DialogReturnCode.Yes,AdditionalParameters);
				
			Cancel = True;
			
		ElsIf Not WriteParameters.Property("NoCheckQuantity")
			And Not Object.UseQuantity
			And OldValues.UseQuantity Then
			
			AdditionalParameters = WriteParameters;
			AdditionalParameters.Insert("CheckingAttribute", "Quantity");
			
			CheckingExistEntriesEnd(DialogReturnCode.Yes,AdditionalParameters);
				
			Cancel = True;
			
		ElsIf WriteParameters.Property("NoCheckQuantity")
			Or WriteParameters.Property("NoCheckAnalyticalDimensions") Then
			
			UpdateAccountsData(Object.UseQuantity, Object.UseAnalyticalDimensions);
			CheckingExistEntriesEnd(WriteParameters.Property("Close"), WriteParameters);
			
		Else
			
			CheckingExistEntriesEnd(WriteParameters.Property("Close"), WriteParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AnalyticalDimensionsOnChange(Item)
	
	If CheckExistAccountsWithAnalyticalDimensionsFlag() Then
		
		Object.UseAnalyticalDimensions = UseAnalyticalDimensions;
		
		MessageText = StrTemplate(NStr("en = 'Cannot save changes. Analytical dimensions option is applied to accounts of %1.'; ru = '???? ?????????????? ?????????????????? ??????????????????. ?????????????????????????? ?????????????????? ?????? ?????????????????????? ?? ???????????? %1.';pl = 'Nie mo??na zapisa?? zmian. Opcja Wymiary analityczne jest zastosowana do kont %1.';es_ES = 'No se pueden guardar los cambios. La variante de dimensiones anal??ticas se aplica a las cuentas de %1.';es_CO = 'No se pueden guardar los cambios. La variante de dimensiones anal??ticas se aplica a las cuentas de %1.';tr = 'De??i??iklikler kaydedilemiyor. Analitik boyutlar se??ene??i %1 hesaplar??na uygulan??yor.';it = 'Impossibile salvare le modifiche. L''opzione di dimensioni analitiche ?? applicata ai conti di %1.';de = 'Fehler beim Speichern von ??nderungen. Option Analytische Messungen ist f??r Konten von %1 verwendet.'"), Object.Ref);
		CommonClientServer.MessageToUser(MessageText,, "Object.UseAnalyticalDimensions");
		
	Else
		UseAnalyticalDimensions = Object.UseAnalyticalDimensions;
		
		If Not UseAnalyticalDimensions Then
			Object.AllowToChangeAnalyticalDimensionsIfAccountHasEntries = UseAnalyticalDimensions;
		EndIf;
	EndIf;

	FormManagement();
	
EndProcedure

&AtClient
Procedure QuantityOnChange(Item)
	
	If CheckExistAccountsWithQuantityFlag() Then
		
		Object.UseQuantity = UseQuantity;
		
		MessageText = StrTemplate(NStr("en = 'Cannot save changes. Quantity option is applied to accounts of %1.'; ru = '???? ?????????????? ?????????????????? ??????????????????. ???????????????????? ?????? ?????????????????????? ?? ???????????? %1.';pl = 'Nie mo??na zapisa?? zmian. Opcja Ilo???? jest zastosowana do kont %1.';es_ES = 'No se pueden guardar los cambios. La variante de cantidad se aplica a las cuentas de %1.';es_CO = 'No se pueden guardar los cambios. La variante de cantidad se aplica a las cuentas de %1.';tr = 'De??i??iklikler kaydedilemiyor. Miktar se??ene??i %1 hesaplar??na uygulanm???? durumda.';it = 'Impossibile salvare le modifiche. L''opzione quantit?? ?? applicata ai conti di %1.';de = 'Fehler beim Speichern von ??nderungen. Option Menge ist f??r Konten von %1 verwendet.'"), Object.Ref);
		CommonClientServer.MessageToUser(MessageText,, "Object.UseQuantity");
		
	Else
		UseQuantity = Object.UseQuantity;
		
		If Not UseQuantity Then
			Object.AllowToChangeQuantitySettingsIfAccountHasEntries = UseQuantity;
		EndIf;
	EndIf;

	FormManagement();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("Close"));
	
EndProcedure

&AtClient
Procedure TypeOfEntriesOnChange(Item)
	
	If Not Object.Ref.IsEmpty() Then
		
		If Object.TypeOfEntries = TypeOfEntries Then
			Return;
		EndIf;
		
		EntriesInfo = AvailableChangeTypeOfEntries(Object.Ref);
		
		If Not (EntriesInfo.Exist Or EntriesInfo.UseTemplates) Then
			TypeOfEntries = Object.TypeOfEntries;
		Else
			Object.TypeOfEntries = TypeOfEntries;
			
			If EntriesInfo.Exist Then
				MessageText = NStr("en = 'Cannot change Type of entries. Accounting entries are already recorded on this chart of accounts.'; ru = '???? ?????????????? ???????????????? ?????? ????????????????. ?????????????????????????? ???????????????? ?????? ?????????????? ?? ???????? ???????? ????????????.';pl = 'Nie mo??na zmieni?? Typu wpis??w. Wpisy ksi??gowe s?? ju?? zapisane na tym planie kont.';es_ES = 'No se puede cambiar el Tipo de entradas de diario. Las entradas contables ya est??n registradas en este diagrama de cuentas.';es_CO = 'No se puede cambiar el Tipo de entradas de diario. Las entradas contables ya est??n registradas en este diagrama de cuentas.';tr = 'Giri?? t??r?? de??i??tirilemiyor. Bu hesap plan??nda kay??tl?? muhasebe giri??leri var.';it = 'Impossibile modificare il tipo di voci. Le voci di contabilit?? sono gi?? registrate in questo piano dei conti.';de = 'Fehler beim ??ndern von Buchungstyp. Buchungen sind bereits in diesem Kontenplan gespeichert.'");
			Else
				MessageText = NStr("en = 'Cannot change Type of entries. This chart of accounts is applied to accounting entries templates.'; ru = '???? ?????????????? ???????????????? ?????? ????????????????. ???????? ???????? ???????????? ?????? ?????????????????????? ?? ???????????????? ?????????????????????????? ????????????????.';pl = 'Nie mo??na zmieni?? Typu wpis??w. Ten plan kont jest zastosowany do szablon??w wpis??w ksi??gowych.';es_ES = 'No se puede cambiar el Tipo de entradas de diario. Este diagrama de cuentas se aplica a las plantillas de entradas contables.';es_CO = 'No se puede cambiar el Tipo de entradas de diario. Este diagrama de cuentas se aplica a las plantillas de entradas contables.';tr = '""Giri?? t??r??"" de??i??tirilemiyor. Bu hesap plan??, muhasebe giri??i ??ablonlar??na uygulanm???? durumda.';it = 'Impossibile modificare il Tipo di voci. Questo piano dei conti ?? applicato ai modelli di voci di contabilit??.';de = 'Fehler beim ??ndern von ""Buchungstyp"". Der Kontenplan ist bereits f??r Buchungsvorlagen verwendet.'");
			EndIf;
			
			CommonClientServer.MessageToUser(MessageText,, "Object.TypeOfEntries");
			
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()

	Items.AllowToChangeAnalyticalDimensionsIfAccountHasEntries.Enabled = Object.UseAnalyticalDimensions;
	Items.AllowToChangeQuantitySettingsIfAccountHasEntries.Enabled = Object.UseQuantity;
	
EndProcedure

&AtServer
Function GetObjectOldValues(NeededValuesArray)
	
	Result = New Structure;
	
	For Each Item In NeededValuesArray Do
		Result.Insert(Item, Object.Ref[Item]);
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CheckingExistEntriesEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		WriteParameters = AdditionalParameters;
		
		If AdditionalParameters.CheckingAttribute = "Quantity" Then
			WriteParameters.Insert("NoCheckQuantity", True);
		ElsIf AdditionalParameters.CheckingAttribute = "AnalyticalDimensions" Then
			WriteParameters.Insert("NoCheckAnalyticalDimensions", True);
		EndIf;
		
		Write(WriteParameters);
		
	EndIf;
	
	If ClosingResult = True Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAccountsData(UseQuantity, UseAnalyticalDimensions)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MasterChartOfAccounts.Ref AS Account
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts
	|	AND (MasterChartOfAccounts.UseAnalyticalDimensions
	|			OR MasterChartOfAccounts.UseQuantity)";
	
	Query.SetParameter("ChartOfAccounts", Object.Ref);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		AccountObject = SelectionDetailRecords.Account.GetObject();
		
		AccountObject.UseQuantity = AccountObject.UseQuantity And UseQuantity;
		AccountObject.UseAnalyticalDimensions = AccountObject.UseAnalyticalDimensions And UseAnalyticalDimensions;
		
		AccountObject.Write();
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CloseForm()
	
	Close();
	
EndProcedure

&AtServerNoContext
Function AvailableChangeTypeOfEntries(ChartOfAccounts)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MasterChartOfAccounts.Ref AS Account
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts";
	
	Query.SetParameter("ChartOfAccounts", ChartOfAccounts);
	
	QueryResult = Query.Execute();
	
	EntriesInfo = New Structure("Exist, UseTemplates", False, False);
	
	If QueryResult.IsEmpty() Then
		Return EntriesInfo;
	EndIf;
	
	AccountsArray = New Array;
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		AccountsArray.Add(SelectionDetailRecords.Account);
	EndDo;
	
	EntriesInfo.Exist = WorkWithArbitraryParameters.CheckExistRegisterEntriesWithExtDimensions(AccountsArray);
	EntriesInfo.UseTemplates = WorkWithArbitraryParameters.CheckExistAccountingEntriesTemplates(AccountsArray);
	
	Return EntriesInfo;
	
EndFunction

&AtServer
Function CheckExistAccountsWithQuantityFlag()
	
	Return Catalogs.ChartsOfAccounts.CheckExistAccountsWithQuantityFlag(Object.Ref);
	
EndFunction

&AtServer
Function CheckExistAccountsWithAnalyticalDimensionsFlag()
	
	Return Catalogs.ChartsOfAccounts.CheckExistAccountsWithAnalyticalDimensionsFlag(Object.Ref);
	
EndFunction 

#EndRegion