# APSupport Menu (v3.0.1) — Allan Pablo

**O que é:** Script de manutenção Windows com **elevação automática**, **logs**, **relatório HTML**, **temas**, **perfis** e utilitários de suporte.

## Como usar
1. Extraia o pacote para uma pasta local (ex.: `C:\APSupport`).
2. Dê **duplo clique** em `Run-APSupportMenu.bat` (ou clique direito » **Executar como administrador**).
   - Alternativa: abra o PowerShell 5.1 como Admin e rode:  
     `Set-ExecutionPolicy Bypass -Scope Process -Force; .\Menu-Suporte-AllanPablo.ps1`
3. Se o Windows marcar o arquivo como "da internet", o script **remove o Zone.Identifier** automaticamente.

## Personalização rápida
- **Tema/Perfil**: opção **36** do menu (persistente em `%ProgramData%\APSupport\config.json`).
- **Perfis**: 
  - **Rápido** e **Completo**: auto-confirmam ações (sem prompts).
  - **Padrão**: pede confirmação.
- **Operador**: definido na primeira execução (também salvo no `config.json`).

## Relatórios e logs
- Logs: `%ProgramData%\APSupport\logs\<timestamp>.log`
- Ao sair, é gerado um **HTML** no Desktop: `APSupport-Relatorio-*.html` com todas as ações (OK/WARN/ERR).

## Dicas
- Use o **A27** para coletar um **pacote de diagnóstico** completo (ZIP no Desktop).
- Antes de remover apps, crie **ponto de restauração** (A19 ou opção do A26).
- Em redes instáveis: rode **A22** e **A12** na sequência.

![PowerShell 5.1](https://img.shields.io/badge/PowerShell-5.1-blue)
![Admin Required](https://img.shields.io/badge/Admin-required-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)