#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetContractVisible();
	
	DefaultGLAccounts = InformationRegisters.CounterpartiesGLAccounts.GetCounterpartiesDefaultGLAccounts();
	
	If Not ValueIsFilled(Parameters.Key.Company)
		And Not ValueIsFilled(Parameters.Key.TaxCategory)
		And Not ValueIsFilled(Parameters.Key.Counterparty)
		And Not ValueIsFilled(Parameters.Key.Contract) Then
		
		IsDefaultRecord = FormAttributeToValue("Record").Selected();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If (Modified Or Parameters.Key.IsEmpty())
		And Not WriteParameters.Property("DontAskNeedToFillEmptyAccounts")
		And NeedToFillEmptyAccounts() Then
		
		Text = NStr("en = 'You have not filled in some of the GL accounts.
			|They will be populated from the generic GL account settings applicable to all counterparties.'; 
			|ru = 'Вы не указали некоторые счета учета.
			|Они будут заполнены из общих настроек счетов учета, применяемых ко всем контрагентам.';
			|pl = 'Nie wypełniono kilku kont księgowych.
			|Zostaną one wypełnione na podstawie ogólnych ustawień kont księgowych, które mają zastosowanie dla wszystkich kontrahentów.';
			|es_ES = 'No ha completado algunas de las cuentas del libro mayor.
			|Se completarán a partir de la configuración de la cuenta del libro mayor genérica aplicable a todas las contrapartes.';
			|es_CO = 'No ha completado algunas de las cuentas del libro mayor.
			|Se completarán a partir de la configuración de la cuenta del libro mayor genérica aplicable a todas las contrapartes.';
			|tr = 'Muhasebe hesaplarından bazılarını doldurmadınız.
			|Tüm cari hesaplara uygulanabilecek jenerik muhasebe hesabı ayarlarından doldurulacaklar.';
			|it = 'Non sono stati compilati alcuni conti mastro.
			| Saranno compilati dalle impostazioni generiche di conto mastro applicabili a tutte le controparti.';
			|de = 'Sie haben einige der Hauptbuch-Konten nicht aufgefüllt.
			|Sie werden aus für alle Geschäftspartner verwendbaren Ober-Einstellungen des Hauptbuch-Kontos automatisch aufgefüllt.'");
		Notification = New NotifyDescription("FillCheckEnd", ThisObject, WriteParameters);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	SetContractVisible();
	
EndProcedure

&AtClient
Procedure CompanyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"), StandardProcessing);
	
EndProcedure

&AtClient
Procedure TaxCategoryChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Tax category'; ru = 'Налогообложение';pl = 'Rodzaj opodatkowania VAT';es_ES = 'Categoría de impuestos';es_CO = 'Categoría de impuestos';tr = 'Vergi kategorisi';it = 'Categoria di imposta';de = 'Steuerkategorie'"), StandardProcessing);
	
EndProcedure

&AtClient
Procedure CounterpartyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), StandardProcessing);
	
EndProcedure

&AtClient
Procedure ContractChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DimensionsChoiceProcessing(Nstr("en='Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"), StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetContractVisible()
	
	UseContracts = Constants.UseContractsWithCounterparties.Get();
	DoOperationsByContracts = (ValueIsFilled(Record.Counterparty)
		AND Not Common.ObjectAttributeValue(Record.Counterparty, "IsFolder")
		AND Common.ObjectAttributeValue(Record.Counterparty, "DoOperationsByContracts"));
	
	Items.Contract.Visible = UseContracts AND DoOperationsByContracts;
	
EndProcedure

&AtClient
Function NeedToFillEmptyAccounts()
	
	For Each Account In DefaultGLAccounts Do
			
		If Not ValueIsFilled(Record[Account.Key])
			And ValueIsFilled(Account.Value) Then
			Return True;
			Break;
		EndIf;
			
	EndDo;
	
	Return False;

EndFunction

&AtClient
Procedure FillCheckEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		FillEmptyGLAccounts();
	EndIf;
	
	If IsGenericGLAccountSettings() 
		And NeedToFillEmptyAccounts() Then
		
		CommonClientServer.MessageToUser(NStr("en = 'You have not filled in some of the GL accounts.'; ru = 'Вы не указали некоторые счета учета.';pl = 'Nie wypełniono kilku kont księgowych.';es_ES = 'No ha completado algunas de las cuentas del libro mayor.';es_CO = 'No ha completado algunas de las cuentas del libro mayor.';tr = 'Muhasebe hesaplarından bazılarını doldurmadınız.';it = 'Non sono stati compilati alcuni conti mastro.';de = 'Sie haben einige der Hauptbuch-Konten nicht aufgefüllt.'"));
	Else
		Write(New Structure("DontAskNeedToFillEmptyAccounts"));
	EndIf;	
	
EndProcedure

&AtClient
Procedure FillEmptyGLAccounts()
	
	For Each GLAccount In DefaultGLAccounts Do
		
		If Not ValueIsFilled(Record[GLAccount.Key]) Then
			Record[GLAccount.Key] = DefaultGLAccounts[GLAccount.Key];
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function IsGenericGLAccountSettings()
	
	Result = False;
	
	If Not ValueIsFilled(Record.Company)
		And Not ValueIsFilled(Record.TaxCategory)
		And Not ValueIsFilled(Record.Counterparty)
		And Not ValueIsFilled(Record.Contract) Then
		
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure DimensionsChoiceProcessing(DimensionName, StandardProcessing)
	
	If IsDefaultRecord Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot change %1.
					|This window includes generic GL account settings applicable to all counterparties.
					|The settings are nonspecific to a certain %1. It must be blank.'; 
					|ru = 'Не удалось изменить %1.
					|Это окно включает в себя общие настройки счетов учета, применимые ко всем контрагентам.
					|Настройки не зависят от определенного %1. Он должен быть пустым.';
					|pl = 'Nie można zmienić %1.
					|To okno zawiera ogólne ustawienia konta księgowego, mające zastosowanie dla wszystkich kontrahentów.
					|Ustawienia nie są specyficzne dla określonego %1. Powinno ono być puste.';
					|es_ES = 'No se puede cambiar %1.
					|Esta ventana incluye la configuración de la cuenta del libro mayor genérica aplicable a todas las contrapartes.
					|La configuración no es específica para un %1determinado. Debe estar en blanco.';
					|es_CO = 'No se puede cambiar %1.
					|Esta ventana incluye la configuración de la cuenta del libro mayor genérica aplicable a todas las contrapartes.
					|La configuración no es específica para un %1determinado. Debe estar en blanco.';
					|tr = '%1 değiştirilemiyor.
					|Bu pencere, tüm cari hesaplara uygulanabilecek jenerik muhasebe hesabı ayarları içeriyor.
					|Ayarlar %1 öğesine özel değil. Boş olmalı.';
					|it = 'Impossibile modificare %1.
					|Questa finestra include le impostazioni generali dei conti mastro applicabili a tutte le controparti.
					|Le impostazioni non sono specifiche per determinati %1. Deve essere vuoto.';
					|de = 'Fehler beim Ändern von %1.
					|Dieses Fenster enthält für alle Geschäftspartner verwendbare Ober-Einstellungen des Hauptbuch-Kontos.
					|Die Einstellungen sind für bestimmte %1 nicht spezifisch. Es muss leer sein.'"), DimensionName);
		CommonClientServer.MessageToUser(MessageText);
		
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion
