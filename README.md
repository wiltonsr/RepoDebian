RepoDebian
============

Script para gerenciar Repositórios Debian. Baseado em https://wiki.debian.org/DebianRepository/Format

```bash
$ ./repo-deb.sh -h
Usage:
  repo-deb.sh -m create|update|delete [-l <location>] [-r <repository>] [-d <distribution>] [-c '<list of components>'] [-a '<list of architectures>']
  repo-deb.sh -h (print this message)
    -m <mode> - one of 'create' or 'update'
      - 'create' - create all folders structure to start an Debian Repository
      - 'update' - update an existing Debian Repository
      - 'delete' - delete an existing Debian Repository, distribution or components
    -l <location> - filesystem location served by a webserver
      (defaults to '/var/www/html')
    -r <repository> - name
      (defaults to 'debian')
    -d <distribution> - specifies a subdirectory in $repo/dists.
      (defaults to 'stable')
    -c <components> - specifies the subdirectories in $repo/dists/$distribution
      (defaults to 'main contrib non-free')
    -a <architectures> - specifies the architectures of repository
      (defaults to 'i386 amd64 all')
      Note: Architecture all is always created
    -f <force> - no prompt for confirmation
```

Modos
-----------
### Flag -m

O script possui 3 modos de execução:
- create: Cria toda a estrutura de pastas necessária para utilização de um Repositório Debian.
- update: Atualiza as listas de pacotes dos Repositórios existentes.
- delete: Remove a estrutura de pastas e atualiza as listas para refletir a nova estrutura.

Localização
-----------
### Flag -l

É o parâmetro responsável por informar a localização do webserver que serve os arquivos do seu repositório.

**Valor padrão:** /var/www/html

Repositório
-----------
### Flag -r

É o parâmetro responsável por informar o nome do Repositório Debian.

**Valor padrão:** debian

**Equivalente no formato de fontes de pacotes:**

deb [http://ftp.debian.org/**`debian`**](http://ftp.debian.org/debian) stretch main contrib non-free

Distribuição
-----------
### Flag -d

É o parâmetro responsável por informar o nome da distribuição.

**Valor padrão:** stable

**Equivalente no formato de fontes de pacotes:**

deb [http://ftp.debian.org/debian](http://ftp.debian.org/debian) **`stretch`** main contrib non-free

Componentes
-----------
### Flag -c

É o parâmetro responsável por informar a lista de componentes presentes na distribuição.

**Valor padrão:** main contrib non-free

**Equivalente no formato de fontes de pacotes:**

deb [http://ftp.debian.org/debian](http://ftp.debian.org/debian) stretch **`main contrib non-free`**

Arquiteturas
-----------
### Flag -a

É o parâmetro responsável por informar a lista de arquiteturas presentes no componente.

**Valor padrão:** i386 amd64 all

Force
-----------
### Flag -f

Flag responsável por remover a interação do script. Caso seja passada o script não faz nenhuma verificação antes de executar as ações. Ideal para set utilizada em scripts automatizados.

Exemplos
-----------

### Criação de um repositório

Criar um repositório chamado `my-repo` com a distribuição `my-distro` e os componentes `comp1 comp2 comp3`. Como os parâmetros `-l` e `-a` não foram passados explicitamente os valores padrões são `/var/www/html` e `i386 amd64 all`, respectivamente.

```bash
$ ./repo-deb.sh -m create -r my-repo -d my-distro -c 'comp1 comp2 comp3'
Creating repository 'my-repo' in '/var/www/html' from 'my-distro' distribution with 'comp1 comp2 comp3' components and 'i386 amd64 all' architectures.

Continue (y/n)? y
proceeding ...

All done!
Put this in your source.list
deb [trusted=yes] http://repository-address.com/my-repo my-distro comp1 comp2 comp3
```

### Atualização de todos os repositórios

Caso não seja passado nenhum parâmetro no modo `update` o script irá ler todos os repositórios válidos e executar a atualização de todos.

```bash
$ ./repo-deb.sh -m update
Updating repository 'debian' in '/var/www/html' from 'stable' distribution with 'contrib main non-free ' components.

Updating repository 'git' in '/var/www/html' from 'stable' distribution with 'contrib main non-free ' components.

Updating repository 'my-repo' in '/var/www/html' from 'my-distro' distribution with 'comp1 comp2 comp3 ' components.

Updating repository 'rambox' in '/var/www/html' from 'stable' distribution with 'contrib main non-free ' components.

Continue (y/n)? y
proceeding ...

All done!
```

### Remoção de um componente do repositório

Remover o componente `main` da distribuição `stable` do repositório `rambox`.

```bash
$ ./repo-deb.sh -m delete -r rambox -d stable -c main
Deleting repository 'rambox' in '/var/www/html' from 'stable' distribution with 'main' components.

Continue (y/n)? y
proceeding ...

All done!
```
