#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.DefaultGLAccounts);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Public

Function GetDefaultGLAccount(DefaultAccountString) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
	DefaultGLAccountsItem = Catalogs.DefaultGLAccounts[DefaultAccountString];
	GLAccount = Common.ObjectAttributeValue(DefaultGLAccountsItem, "GLAccount");
	
	If ValueIsFilled(GLAccount) Then
		Return GLAccount;
	Else
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Default GL account for %1 is not set. Please go to Company - Default GL Accounts and specify it.'; ru = 'Счет учета по умолчанию для %1 не заполнен. Пожалуйста, перейдите в Предприятие - Счета учета по умолчанию и укажите его.';pl = 'Domyślne konto księgowe dla %1 nie jest ustawione. Przejdź do Firma - Domyślne konto księgowe i określ go.';es_ES = 'Cuenta del libro mayor por defecto para %1 no se ha establecido. Por favor, ir a la Empresa - Cuentas del libro mayor Por defecto y especificarla.';es_CO = 'Cuenta del libro mayor por defecto para %1 no se ha establecido. Por favor, ir a la Empresa - Cuentas del libro mayor Por defecto y especificarla.';tr = '%1 için varsayılan muhasebe hesabı ayarlanmadı. Lütfen İş yeri - Varsayılan Muhasebe Hesapları''na gidip bu hesabı belirleyin.';it = 'Il conto mastro predefinito per %1 non è definito. Per piacere andare in Azienda - Conti mastro predefiniti e specificarlo.';de = 'Das Standard-Hauptbuch-Konto für %1 wurde nicht festgelegt. Bitte gehen Sie zu Firma- Standard-Hauptbuch-Konten und geben Sie sie an.'"),
			DefaultGLAccountsItem.Description),
			DefaultGLAccountsItem,
			"GLAccount");
		Return ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
EndFunction

#EndRegion

#EndIf