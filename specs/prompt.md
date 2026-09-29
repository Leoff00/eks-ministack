# Descrição:

Monte um roadmap do que preciso para subir um EKS local na minha maquina utilizando apenas o ministack, uma abstração dos serviços da AWS e substituto do localstack que contem o serviço necessário. Consulte a doc: *https://ministack.org/* e também o repo do github: *https://github.com/ministackorg/ministack*

1. Para começar, quero que utilize terraform apontando para o ambiente AWS local que o ministack oferece (test-test-us-east-1), após isso quero o EKS (e algum serviço necessário) via Terraform, ja sei terraform mas seria para reforçar meu conhecimento.

2. Eu ja tenho os fundamentos do Kubernetes, porem nunca realizei de fato uma subida de um serviço EKS do absoluto zero, apenas ja o usei configurado e gostaria justamente de saber o que é necessário além de apenas subir um Cluster EKS, também enfatizo que ja tenho ciencia de ambiente AWS, porém o gap é apenas subir um EKS do zero.

3. Além de subir um Cluster EKS, também gostaria de dicas do que mais é utilizado para compor um cluster EKS, eu sei que existe o Argo CD, porém não tenho interesse em usa-lo neste projeto, pois nao estou montando nenhuma pipeline CI/CD e ja tenho um homelab configurado com o Gitea para um Kind local (o que e mais simples que um EKS), no entanto tenho interesse de saber o que é comum/padrao de mercado para utilizar.

4. Por mim monte uma app simples onde eu irei inserir esta app como deployment e inseri-la dentro de um worker node no EKS apenas para testar a funcionalidade pratica final.
